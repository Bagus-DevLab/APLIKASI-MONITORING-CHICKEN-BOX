/// Generic pagination wrapper for all paginated API responses
/// 
/// Based on API_CONTRACT.md Section 6: Pagination Format
/// 
/// Standard pagination response structure:
/// ```json
/// {
///   "data": [...],
///   "total": 50,
///   "page": 1,
///   "limit": 20,
///   "total_pages": 3
/// }
/// ```
/// 
/// Usage:
/// ```dart
/// final response = await dio.get('/api/devices/');
/// final paginatedDevices = PaginatedResponse<Device>.fromJson(
///   response.data,
///   Device.fromJson,
/// );
/// 
/// print('Loaded ${paginatedDevices.itemCount} devices');
/// if (paginatedDevices.hasNextPage) {
///   // Load next page
/// }
/// ```
class PaginatedResponse<T> {
  /// List of items in the current page
  final List<T> data;

  /// Total number of items across all pages
  final int total;

  /// Current page number (1-indexed)
  final int page;

  /// Number of items per page
  final int limit;

  /// Total number of pages
  final int totalPages;

  PaginatedResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  /// Create PaginatedResponse from JSON
  /// 
  /// Parameters:
  /// - [json]: The JSON response from the API
  /// - [fromJsonT]: Function to deserialize each item in the data array
  /// 
  /// Example:
  /// ```dart
  /// PaginatedResponse<Device>.fromJson(
  ///   response.data,
  ///   Device.fromJson,
  /// )
  /// ```
  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PaginatedResponse<T>(
      data: (json['data'] as List)
          .map((item) => fromJsonT(item as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
      totalPages: json['total_pages'] as int,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) toJsonT) {
    return {
      'data': data.map((item) => toJsonT(item)).toList(),
      'total': total,
      'page': page,
      'limit': limit,
      'total_pages': totalPages,
    };
  }

  /// Check if there is a next page
  bool get hasNextPage => page < totalPages;

  /// Check if there is a previous page
  bool get hasPreviousPage => page > 1;

  /// Check if the data list is empty
  bool get isEmpty => data.isEmpty;

  /// Check if the data list is not empty
  bool get isNotEmpty => data.isNotEmpty;

  /// Get the number of items in the current page
  int get itemCount => data.length;

  /// Check if this is the first page
  bool get isFirstPage => page == 1;

  /// Check if this is the last page
  bool get isLastPage => page == totalPages;

  /// Get the starting item number (1-indexed)
  /// Example: Page 2 with limit 20 starts at item 21
  int get startItemNumber => (page - 1) * limit + 1;

  /// Get the ending item number (1-indexed)
  /// Example: Page 2 with limit 20 and 15 items ends at item 35
  int get endItemNumber => startItemNumber + itemCount - 1;

  @override
  String toString() {
    return 'PaginatedResponse<$T>(page: $page/$totalPages, items: $itemCount/$total)';
  }
}
