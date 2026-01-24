import 'package:flutter/material.dart';
import '../services/app_startup_service.dart';

/// Pool durumunu gösteren widget
/// Admin veya debug ekranlarında kullanılabilir
class PoolStatusWidget extends StatefulWidget {
  const PoolStatusWidget({super.key});

  @override
  State<PoolStatusWidget> createState() => _PoolStatusWidgetState();
}

class _PoolStatusWidgetState extends State<PoolStatusWidget> {
  final AppStartupService _appStartup = AppStartupService();
  
  Map<String, dynamic>? _poolStatus;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadPoolStatus();
  }

  Future<void> _loadPoolStatus() async {
    setState(() => _isLoading = true);
    
    final status = await _appStartup.getPoolStatus();
    
    setState(() {
      _poolStatus = status;
      _isLoading = false;
    });
  }

  Future<void> _forceUpdate() async {
    setState(() => _isUpdating = true);
    
    final success = await _appStartup.forceUpdatePool();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
            ? '✅ Pool güncellendi!' 
            : '❌ Güncelleme başarısız'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      
      // Status'u yenile
      await _loadPoolStatus();
    }
    
    setState(() => _isUpdating = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final exists = _poolStatus?['exists'] ?? false;

    if (!exists) {
      return Card(
        color: Colors.orange[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.warning, size: 48, color: Colors.orange[700]),
              const SizedBox(height: 8),
              Text(
                'Match Pool Yok',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _poolStatus?['message'] ?? 'Pool henüz oluşturulmamış',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isUpdating ? null : _forceUpdate,
                icon: _isUpdating 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
                label: Text(_isUpdating ? 'Güncelleniyor...' : 'Pool Oluştur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Pool var - bilgileri göster
    final totalMatches = _poolStatus?['totalMatches'] ?? 0;
    final leagues = _poolStatus?['leagues'] ?? 0;
    final hoursSinceUpdate = _poolStatus?['hoursSinceUpdate'] ?? 0;
    final isStale = _poolStatus?['isStale'] ?? false;

    return Card(
      color: isStale ? Colors.orange[50] : Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isStale ? Icons.warning : Icons.check_circle,
                  color: isStale ? Colors.orange[700] : Colors.green[700],
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Match Pool Durumu',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isStale ? Colors.orange[900] : Colors.green[900],
                        ),
                      ),
                      Text(
                        isStale 
                          ? 'Güncelleme gerekiyor' 
                          : 'Güncel ve aktif',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // İstatistikler
            _buildStatRow('Toplam Maç', '$totalMatches', Icons.sports_soccer),
            _buildStatRow('Lig Sayısı', '$leagues', Icons.emoji_events),
            _buildStatRow(
              'Son Güncelleme', 
              '$hoursSinceUpdate saat önce', 
              Icons.schedule,
            ),
            
            const SizedBox(height: 16),
            
            // Güncelleme butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUpdating ? null : _forceUpdate,
                icon: _isUpdating 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh),
                label: Text(_isUpdating ? 'Güncelleniyor...' : 'Manuel Güncelle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isStale ? Colors.orange : Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
