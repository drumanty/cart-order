import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'add_product_screen.dart';
import 'catalog_support.dart';
import 'cloudinary_upload_service.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen>
    with CatalogState<AdminProductsScreen> {
  final _search = TextEditingController();
  String _query = '';
  final _busy = <String>{};

  List<Map<String, dynamic>> get _items {
    final text = _query.trim().toLowerCase();
    if (text.isEmpty) return catalogProducts;
    return catalogProducts.where((item) {
      return [
        item['productName'],
        item['category'],
        item['sellerName'],
        item['sellerShopName'],
        item['id'],
        item['status'],
        item['stockStatus'],
      ].join(' ').toLowerCase().contains(text);
    }).toList();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _notice(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _addProduct() {
    if (catalogCategories.isEmpty) {
      _notice('Create a category first.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(categories: catalogCategories),
      ),
    );
  }

  Future<void> _editProduct(String id) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProductEditor(id: id, categories: catalogCategories),
    );
    if (saved == true && mounted) _notice('Product updated successfully.');
  }

  Future<void> _editCategory(
    DocumentSnapshot<Map<String, dynamic>>? category,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _CategoryEditor(category: category, categoryNames: catalogCategories),
    );
    if (saved == true && mounted) {
      _notice(category == null ? 'Category created.' : 'Category updated.');
    }
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteProduct(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    if (!await _confirm(
      'Delete product?',
      item['productName'].toString() + ' will be removed permanently.',
    ))
      return;
    setState(() => _busy.add(id));
    try {
      await FirebaseFirestore.instance.collection('products').doc(id).delete();
      if (mounted) _notice('Product deleted.');
    } catch (error) {
      if (mounted) _notice(catalogError(error));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _toggleStock(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    if (_busy.contains(id)) return;
    final inStock = item['inStock'] != true;
    setState(() => _busy.add(id));
    try {
      await FirebaseFirestore.instance.collection('products').doc(id).update({
        'inStock': inStock,
        'stockStatus': inStock ? 'In Stock' : 'Out of Stock',
        'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (mounted) _notice(catalogError(error));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _categories() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _CategoryManager(onEdit: _editCategory, onDelete: _deleteCategory),
    );
  }

  Future<void> _deleteCategory(
    BuildContext pageContext,
    DocumentSnapshot<Map<String, dynamic>> category,
  ) async {
    final name = (category.data()?['name'] ?? '').toString();
    try {
      final assigned = await FirebaseFirestore.instance
          .collection('products')
          .where('category', isEqualTo: name)
          .limit(1)
          .get();
      if (assigned.docs.isNotEmpty) {
        if (pageContext.mounted) {
          ScaffoldMessenger.of(pageContext).showSnackBar(
            const SnackBar(
              content: Text(
                'Move or edit its products before deleting this category.',
              ),
            ),
          );
        }
        return;
      }
      if (!pageContext.mounted) return;
      final yes =
          await showDialog<bool>(
            context: pageContext,
            builder: (dialog) => AlertDialog(
              title: const Text('Delete category?'),
              content: Text(name + ' will be removed.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ) ??
          false;
      if (yes) await category.reference.delete();
    } catch (error) {
      if (pageContext.mounted) {
        ScaffoldMessenger.of(
          pageContext,
        ).showSnackBar(SnackBar(content: Text(catalogError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: .5,
        title: const Text('Admin Product Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Manage categories',
            onPressed: _categories,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProduct,
        backgroundColor: const Color(0xFF0052FF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (text) => setState(() => _query = text),
                    decoration: _input('Search product, seller or category')
                        .copyWith(
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _search.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _editCategory(null),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  tooltip: 'Add category',
                ),
              ],
            ),
          ),
          if (categoryFailure != null) catalogNotice(),
          Expanded(
            child: catalogLoading || catalogFailure != null
                ? catalogNotice()
                : _items.isEmpty
                ? const Center(child: Text('No products found.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: _items.length,
                    itemBuilder: (_, index) {
                      final item = _items[index];
                      final id = item['id'].toString();
                      return _ProductCard(
                        item: item,
                        busy: _busy.contains(id),
                        onEdit: () => _editProduct(id),
                        onDelete: () => _deleteProduct(item),
                        onStock: () => _toggleStock(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.item,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onStock,
  });
  final Map<String, dynamic> item;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onStock;

  @override
  Widget build(BuildContext context) {
    final stock = item['inStock'] == true;
    final active = item['status'] == 'Approved';
    final color = active ? Colors.green : Colors.orange;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        shape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: catalogImage(
            item['frontImage'].toString(),
            width: 52,
            height: 52,
          ),
        ),
        title: Text(
          item['productName'].toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          item['category'].toString() + ' • ' + item['sellingPrice'].toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _Badge(text: item['status'].toString(), color: color),
        children: [
          const Divider(),
          Row(
            children: [
              Expanded(
                child: _Preview(
                  label: 'Front image',
                  url: item['frontImage'].toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Preview(
                  label: 'Back image',
                  url: item['backImage'].toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Detail('Seller', item['sellerShopName'] ?? item['sellerName']),
          _Detail('Stock', stock ? 'In Stock' : 'Out of Stock'),
          _Detail('Package', item['unitTypes']),
          _Detail('MOQ', item['minOrderQuantity']),
          _Detail('Unit price', item['unitPrice']),
          _Detail('MRP', item['mrp']),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Product'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: busy ? null : onStock,
                tooltip: stock ? 'Mark out of stock' : 'Mark in stock',
                icon: Icon(
                  stock ? Icons.remove_shopping_cart : Icons.inventory,
                ),
              ),
              IconButton(
                onPressed: busy ? null : onDelete,
                color: Colors.red,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryManager extends StatelessWidget {
  const _CategoryManager({required this.onEdit, required this.onDelete});
  final Future<void> Function(DocumentSnapshot<Map<String, dynamic>> category)
  onEdit;
  final Future<void> Function(
    BuildContext,
    DocumentSnapshot<Map<String, dynamic>>,
  )
  onDelete;

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Manage Categories',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('categories').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text(catalogError(snapshot.error!)));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs.toList()
            ..sort(
              (a, b) => (a.data()['name'] ?? '').toString().compareTo(
                (b.data()['name'] ?? '').toString(),
              ),
            );
          if (docs.isEmpty)
            return const Center(child: Text('No categories yet.'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final category = docs[index];
              final data = category.data();
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: catalogImage(
                      (data['imageUrl'] ?? '').toString(),
                      width: 46,
                      height: 46,
                    ),
                  ),
                  title: Text((data['name'] ?? '').toString()),
                  subtitle: const Text('Edit name or image'),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        onPressed: () => onEdit(category),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () => onDelete(context, category),
                        color: Colors.red,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({required this.category, required this.categoryNames});
  final DocumentSnapshot<Map<String, dynamic>>? category;
  final List<String> categoryNames;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  XFile? _image;
  Uint8List? _bytes;
  bool _saving = false;
  bool get _editing => widget.category != null;
  Map<String, dynamic> get _old => widget.category?.data() ?? {};

  @override
  void initState() {
    super.initState();
    _name.text = (_old['name'] ?? '').toString();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted)
      setState(() {
        _image = file;
        _bytes = bytes;
      });
  }

  String _id(String name) {
    final id = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return id.isEmpty
        ? 'category-' + DateTime.now().millisecondsSinceEpoch.toString()
        : id;
  }

  void _notice(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = _name.text.trim();
    final oldName = (_old['name'] ?? '').toString();
    final exists = widget.categoryNames.any(
      (item) => item.toLowerCase() == name.toLowerCase() && item != oldName,
    );
    if (exists) {
      _notice('A category with this name already exists.');
      return;
    }
    setState(() => _saving = true);
    try {
      var imageUrl = (_old['imageUrl'] ?? '').toString();
      if (_image != null) {
        imageUrl = await CloudinaryUploadService.uploadImage(
          image: _image!,
          uploadPreset: CloudinaryUploadService.categoryPreset,
        );
      }
      final ref =
          widget.category?.reference ??
          FirebaseFirestore.instance.collection('categories').doc(_id(name));
      final data = {
        'name': name,
        'imageUrl': imageUrl,
        'imagePath': '',
        'updatedBy': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (_editing) {
        await ref.update(data);
        if (oldName != name) {
          final products = await FirebaseFirestore.instance
              .collection('products')
              .where('category', isEqualTo: oldName)
              .get();
          if (products.docs.length > 450) {
            throw StateError('Too many products to rename at once.');
          }
          final batch = FirebaseFirestore.instance.batch();
          for (final product in products.docs) {
            batch.update(product.reference, {
              'category': name,
              'updatedBy': user.uid,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          if (products.docs.isNotEmpty) await batch.commit();
        }
      } else {
        await ref.set({
          ...data,
          'createdBy': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) Navigator.pop(context, true);
    } on CloudinaryUploadException catch (error) {
      _notice(error.message);
    } catch (error) {
      _notice(catalogError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: _editing ? 'Edit Category' : 'Add Category',
      saving: _saving,
      child: Form(
        key: _form,
        child: ListView(
          children: [
            TextFormField(
              controller: _name,
              decoration: _input('Category name'),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return 'Enter a category name';
                return name.length > 100 ? 'Use 100 characters or fewer' : null;
              },
            ),
            const SizedBox(height: 16),
            _ImageCard(
              bytes: _bytes,
              imageUrl: (_old['imageUrl'] ?? '').toString(),
              label: 'Choose category image',
              onTap: _saving ? null : _pick,
            ),
            const SizedBox(height: 24),
            _SaveButton(
              saving: _saving,
              label: _editing ? 'Save Category Changes' : 'Save Category',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({required this.id, required this.categories});
  final String id;
  final List<String> categories;

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sellerPrice = TextEditingController();
  final _margin = TextEditingController();
  final _actual = TextEditingController();
  final _mrp = TextEditingController();
  final _unitPrice = TextEditingController();
  final _mrpUnit = TextEditingController();
  final _moq = TextEditingController();
  final _qty = TextEditingController();
  final _unitType = TextEditingController();
  final _rating = TextEditingController();
  final _warranty = TextEditingController();
  final _description = TextEditingController();
  Map<String, dynamic>? _original;
  String? _category;
  String? _sellerId;
  String _status = 'Approved';
  bool _stock = true;
  XFile? _front;
  XFile? _back;
  Uint8List? _frontBytes;
  Uint8List? _backBytes;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_sellerPrice, _margin, _mrp, _qty]) {
      c.addListener(_calculate);
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _sellerPrice,
      _margin,
      _actual,
      _mrp,
      _unitPrice,
      _mrpUnit,
      _moq,
      _qty,
      _unitType,
      _rating,
      _warranty,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _text(dynamic value) => (value ?? '').toString();
  double? _number(dynamic value) =>
      double.tryParse(_text(value).replaceAll(RegExp('[^0-9.-]'), ''));
  String _money(dynamic value) {
    final number = _number(value);
    return number == null ? '' : number.toStringAsFixed(2);
  }

  void _set(TextEditingController c, double? number) {
    final value = number == null ? '' : number.toStringAsFixed(2);
    if (c.text != value) c.text = value;
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.id)
          .get();
      if (!doc.exists) throw StateError('Product no longer exists.');
      final d = doc.data()!;
      if (!mounted) return;
      setState(() {
        _original = d;
        _name.text = _text(d['productName']);
        _sellerPrice.text = _money(
          d['sellerSellingPrice'] ?? d['sellingPrice'],
        );
        _margin.text = _money(d['marginPercent'] ?? 0);
        _actual.text = _money(d['actualSellingPrice'] ?? d['sellingPrice']);
        _mrp.text = _money(d['mrp']);
        _unitPrice.text = _money(d['unitPrice']);
        _mrpUnit.text = _money(d['mrpUnitPrice']);
        _moq.text = _text(d['minOrderQuantity']);
        _qty.text = _text(d['howManyProductsInUnit']);
        _unitType.text = _text(d['unitTypes']);
        _rating.text = _text(d['currentRating']);
        _warranty.text = _text(d['warranty']);
        _description.text = _text(d['description']);
        _category = _text(d['category']);
        _sellerId = _text(d['sellerId']);
        _status = d['status'] == 'Inactive' ? 'Inactive' : 'Approved';
        _stock = d['inStock'] == true;
        _loading = false;
      });
      _calculate();
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        _notice(catalogError(error));
      }
    }
  }

  void _calculate() {
    final seller = _number(_sellerPrice.text);
    final margin = _number(_margin.text);
    final mrp = _number(_mrp.text);
    final qty = int.tryParse(_qty.text.trim());
    if (seller == null || seller < 0 || margin == null || margin < 0) {
      _set(_actual, null);
      _set(_unitPrice, null);
      _set(_mrpUnit, null);
      return;
    }
    final actual = seller * (1 + margin / 100);
    _set(_actual, actual);
    _set(_unitPrice, qty == null || qty < 1 ? null : actual / qty);
    _set(_mrpUnit, mrp == null || qty == null || qty < 1 ? null : mrp / qty);
  }

  Future<void> _pick(bool front) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (mounted)
      setState(() {
        if (front) {
          _front = image;
          _frontBytes = bytes;
        } else {
          _back = image;
          _backBytes = bytes;
        }
      });
  }

  void _notice(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    _calculate();
    if (_saving || !_form.currentState!.validate() || _original == null) return;
    if (_category == null || !widget.categories.contains(_category)) {
      _notice('Select a valid category.');
      return;
    }
    if (_sellerId == null || _sellerId!.isEmpty) {
      _notice('Select an approved seller.');
      return;
    }
    final base = _number(_sellerPrice.text);
    final margin = _number(_margin.text);
    final mrp = _number(_mrp.text);
    final moq = int.tryParse(_moq.text.trim());
    final qty = int.tryParse(_qty.text.trim());
    if (base == null ||
        base < 0 ||
        margin == null ||
        margin < 0 ||
        margin > 100 ||
        mrp == null ||
        moq == null ||
        moq < 1 ||
        qty == null ||
        qty < 1) {
      _notice('Enter valid prices, margin and positive quantities.');
      return;
    }
    final actual = base * (1 + margin / 100);
    if (mrp < actual) {
      _notice('MRP must be at least the actual selling price.');
      return;
    }
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('Please sign in again.');
      final sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_sellerId)
          .get();
      final seller = sellerDoc.data();
      if (seller == null ||
          seller['userType'] != 'Seller' ||
          seller['accountStatus'] != 'approved') {
        throw StateError('Choose an approved seller.');
      }
      var frontUrl = _text(_original!['frontImage']);
      var backUrl = _text(_original!['backImage']);
      if (_front != null) {
        frontUrl = await CloudinaryUploadService.uploadImage(
          image: _front!,
          uploadPreset: CloudinaryUploadService.productPreset,
        );
      }
      if (_back != null) {
        backUrl = await CloudinaryUploadService.uploadImage(
          image: _back!,
          uploadPreset: CloudinaryUploadService.productPreset,
        );
      }
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.id)
          .update({
            'productName': _name.text.trim(),
            'category': _category,
            'sellerId': sellerDoc.id,
            'sellerName':
                (seller['firstName'] ?? '').toString() +
                ' ' +
                (seller['lastName'] ?? '').toString(),
            'sellerShopName': _text(seller['shopName']),
            'sellerShopAddress': _text(seller['shopAddress']),
            'sellerSellingPrice': base,
            'marginPercent': margin,
            'actualSellingPrice': actual,
            'sellingPrice': actual,
            'mrp': mrp,
            'unitPrice': actual / qty,
            'mrpUnitPrice': mrp / qty,
            'minOrderQuantity': moq,
            'howManyProductsInUnit': qty,
            'unitTypes': _unitType.text.trim(),
            'currentRating': _rating.text.trim(),
            'warranty': _warranty.text.trim(),
            'description': _description.text.trim(),
            'frontImage': frontUrl,
            'backImage': backUrl,
            'sideImage': _text(_original!['sideImage']),
            'status': _status,
            'isActive': _status == 'Approved',
            'inStock': _stock,
            'stockStatus': _stock ? 'In Stock' : 'Out of Stock',
            'updatedBy': user.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) Navigator.pop(context, true);
    } on CloudinaryUploadException catch (error) {
      _notice(error.message);
    } catch (error) {
      _notice(catalogError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const _Sheet(
        title: 'Edit Product',
        child: Center(child: CircularProgressIndicator()),
      );
    if (_original == null)
      return const _Sheet(
        title: 'Edit Product',
        child: Center(child: Text('Product data could not be loaded.')),
      );
    return _Sheet(
      title: 'Edit Product',
      saving: _saving,
      child: Form(
        key: _form,
        child: ListView(
          children: [
            const Text(
              'Product photos',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ImageCard(
                    bytes: _frontBytes,
                    imageUrl: _text(_original!['frontImage']),
                    label: 'Replace front image',
                    onTap: _saving ? null : () => _pick(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ImageCard(
                    bytes: _backBytes,
                    imageUrl: _text(_original!['backImage']),
                    label: 'Replace back image',
                    onTap: _saving ? null : () => _pick(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _field(_name, 'Product name', required: true),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: widget.categories.contains(_category) ? _category : null,
              isExpanded: true,
              decoration: _input('Category'),
              items: widget.categories
                  .map(
                    (name) => DropdownMenuItem(value: name, child: Text(name)),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _category = value),
              validator: (value) => value == null ? 'Select a category' : null,
            ),
            const SizedBox(height: 12),
            _SellerField(
              value: _sellerId,
              enabled: !_saving,
              onChanged: (value) => setState(() => _sellerId = value),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pricing',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _decimal(_sellerPrice, 'Seller price (₹)')),
                const SizedBox(width: 12),
                Expanded(child: _decimal(_margin, 'Margin (%)')),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _actual,
              readOnly: true,
              decoration: _input('Actual selling price (₹)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _decimal(_mrp, 'MRP (₹)')),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unitPrice,
                    readOnly: true,
                    decoration: _input('Unit price (₹)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mrpUnit,
              readOnly: true,
              decoration: _input('MRP unit price (₹)'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Packaging and details',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _integer(_moq, 'Min order quantity')),
                const SizedBox(width: 12),
                Expanded(child: _integer(_qty, 'Qty in unit')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_unitType, 'Package / unit type')),
                const SizedBox(width: 12),
                Expanded(child: _field(_rating, 'Current rating')),
              ],
            ),
            const SizedBox(height: 12),
            _field(_warranty, 'Warranty'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              decoration: _input('Description'),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: _input('Product status'),
              items: const [
                DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _status = value ?? 'Approved'),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('In stock'),
              subtitle: Text(
                _stock
                    ? 'Customers can order this product.'
                    : 'Shown as out of stock.',
              ),
              value: _stock,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _stock = value),
            ),
            const SizedBox(height: 20),
            _SaveButton(
              saving: _saving,
              label: 'Save Product Changes',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
  }) {
    return TextFormField(
      controller: c,
      decoration: _input(label),
      validator: required
          ? (value) {
              return (value?.trim() ?? '').isEmpty ? 'Required' : null;
            }
          : null,
    );
  }

  Widget _decimal(TextEditingController c, String label) => TextFormField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: _input(label),
    validator: (value) {
      final n = _number(value);
      return n == null || n < 0 ? 'Enter a valid amount' : null;
    },
  );
  Widget _integer(TextEditingController c, String label) => TextFormField(
    controller: c,
    keyboardType: TextInputType.number,
    decoration: _input(label),
    validator: (value) {
      final n = int.tryParse(value?.trim() ?? '');
      return n != null && n > 0 ? null : 'Enter a positive number';
    },
  );
}

class _SellerField extends StatelessWidget {
  const _SellerField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'Seller')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text(catalogError(snapshot.error!));
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final sellers = snapshot.data!.docs
            .where((doc) => doc.data()['accountStatus'] == 'approved')
            .toList();
        final selected = sellers.any((doc) => doc.id == value) ? value : null;
        return DropdownButtonFormField<String>(
          value: selected,
          isExpanded: true,
          decoration: _input('Assign seller'),
          items: sellers.map((doc) {
            final d = doc.data();
            final shop = (d['shopName'] ?? '').toString();
            final name =
                (d['firstName'] ?? '').toString() +
                ' ' +
                (d['lastName'] ?? '').toString();
            return DropdownMenuItem(
              value: doc.id,
              child: Text(shop + ' — ' + name, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
          validator: (value) =>
              value == null ? 'Select an approved seller' : null,
        );
      },
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.child, this.saving = false});
  final String title;
  final Widget child;
  final bool saving;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * .92,
        decoration: const BoxDecoration(
          color: Color(0xFFF7F8FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(padding: const EdgeInsets.all(20), child: child),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.bytes,
    required this.imageUrl,
    required this.label,
    required this.onTap,
  });
  final Uint8List? bytes;
  final String imageUrl;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final Widget image = bytes != null
        ? Image.memory(bytes!, fit: BoxFit.cover)
        : imageUrl.isNotEmpty
        ? Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.image_not_supported_outlined),
          )
        : const Icon(
            Icons.add_photo_alternate_outlined,
            size: 30,
            color: Color(0xFF0052FF),
          );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 132,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Center(child: image),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xB3000000),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(11),
                  ),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.label, required this.url});
  final String label;
  final String url;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AspectRatio(
        aspectRatio: 1.6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: catalogImage(
            url,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ],
  );
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label;
  final dynamic value;
  @override
  Widget build(BuildContext context) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.saving,
    required this.label,
    required this.onPressed,
  });
  final bool saving;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    width: double.infinity,
    child: FilledButton(
      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0052FF)),
      onPressed: saving ? null : onPressed,
      child: saving
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(label),
    ),
  );
}

InputDecoration _input(String hint) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
);
