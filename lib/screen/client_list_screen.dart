import 'package:flutter/material.dart';
import '../model/client_model.dart';
import '../core/client_supabase_service.dart';
import 'cases_screen.dart';
import '../database/notification_db.dart';
import 'edit_client_screen.dart'; // ✅ أضفنا الاستيراد

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  ClientListScreenState createState() => ClientListScreenState();
}

class ClientListScreenState extends State<ClientListScreen> {
  List<Client> allClients = [];
  List<Client> filteredClients = [];
  Set<String> selectedClientIds = {};
  bool selectionMode = false;
  bool _isLoading = true;
  TextEditingController searchController = TextEditingController();
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadClients();
    _loadUnreadCount();
  }

  void _showClientDetails(Client client) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              // keep space for keyboard if any
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      child: Text(
                        client.name.isNotEmpty
                            ? client.name.characters.first
                            : '?',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        client.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'تعديل',
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditClientScreen(client: client),
                          ),
                        ).then((_) => _loadClients());
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _detailRow('الهاتف', client.phone ?? '-'),
                _detailRow('العنوان', client.address ?? '-'),
                _detailRow('ملاحظات', client.notes ?? '-'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('إغلاق'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _loadClients() async {
    try {
      final clients = await ClientSupabaseService.fetchClients();
      setState(() {
        allClients = clients;
        allClients.sort((a, b) => a.id.compareTo(b.id));
        filteredClients = List.from(allClients);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('فشل تحميل العملاء: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('فشل تحميل قائمة العملاء')));
    }
  }

  Future<void> deleteSelectedClients() async {
    for (final id in selectedClientIds) {
      await ClientSupabaseService.deleteClient(id);
    }
    setState(() {
      selectedClientIds.clear();
      selectionMode = false;
    });
    _loadClients();
  }

  void _loadUnreadCount() async {
    final count = await NotificationDB.getUnreadCount();
    setState(() => unreadCount = count);
  }

  void _filterClients(String query) {
    setState(() {
      filteredClients = allClients
          .where((client) =>
              client.name.contains(query) || client.phone.contains(query))
          .toList();
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      selectionMode = !selectionMode;
      selectedClientIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      selectedClientIds.contains(id)
          ? selectedClientIds.remove(id)
          : selectedClientIds.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'قائمة العملاء (${filteredClients.length})',
          style: theme.textTheme.titleLarge,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loadClients,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        
         
        
          IconButton(
            icon: Icon(selectionMode ? Icons.close : Icons.select_all),
            onPressed: _toggleSelectionMode,
            tooltip: selectionMode ? 'إلغاء التحديد' : 'تحديد عملاء',
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/notifications',
                  ).then((_) => _loadUnreadCount());
                },
                tooltip: 'الإشعارات',
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 11,
                  top: 11,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'الإعدادات',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم أو الهاتف',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: _filterClients,
                  ),
                ),
                Expanded(
                  child: filteredClients.isEmpty
                      ? const Center(child: Text('لا يوجد عملاء حالياً'))
                      : ListView.builder(
                          itemCount: filteredClients.length,
                          itemBuilder: (context, index) {
                            final client = filteredClients[index];
                            final isSelected =
                                selectedClientIds.contains(client.id);

                            return Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              color: selectionMode && isSelected
                                  ? Colors.red[100]
                                  : theme.cardColor,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: selectionMode
                                    ? Checkbox(
                                        activeColor: Colors.red,
                                        value: isSelected,
                                        onChanged: (_) {
                                          _toggleSelection(client.id);
                                        },
                                      )
                                    : const Icon(Icons.person),
                                title: Text(client.name),
                                subtitle: Text(
                                  'ID: ${client.id} | الهاتف: ${client.phone}',
                                ),
                                trailing: selectionMode
                                    ? null
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              color: Colors.orange,
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      EditClientScreen(
                                                    client: client,
                                                  ),
                                                ),
                                              ).then((value) {
                                                if (value == true) {
                                                  _loadClients();
                                                }
                                              });
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.folder_open,
                                              color: Colors.blueAccent,
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => CasesScreen(
                                                    clientId:
                                                        client.localId ?? 0,
                                                    clientName: client.name,
                                                    firebaseClientId: client.id,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                onTap: selectionMode
                                    ? () => _toggleSelection(client.id)
                                    : () => _showClientDetails(client),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton.extended(
              heroTag: 'add',
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.black,
              onPressed: () {
                Navigator.pushNamed(context, '/add-client').then((value) {
                  if (value == true) {
                    _loadClients();
                  }
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('إضافة عميل'),
            ),
            FloatingActionButton.extended(
              heroTag: 'delete',
              backgroundColor:
                  selectionMode ? Colors.red : theme.colorScheme.primary,
              foregroundColor: Colors.black,
              onPressed: selectionMode
                  ? () {
                      if (selectedClientIds.isNotEmpty) {
                        deleteSelectedClients();
                      }
                    }
                  : _toggleSelectionMode,
              icon: const Icon(Icons.delete),
              label: Text(selectionMode ? 'تأكيد الحذف' : 'مسح عميل'),
            ),
            if (selectionMode)
              FloatingActionButton.extended(
                heroTag: 'cancel',
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.black,
                onPressed: () {
                  setState(() {
                    selectionMode = false;
                    selectedClientIds.clear();
                  });
                },
                icon: const Icon(Icons.cancel),
                label: const Text('إلغاء'),
              ),
          ],
        ),
      ),
    );
  }
}
