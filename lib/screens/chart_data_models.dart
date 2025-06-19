// lib/models/chart_data_models.dart

// Dành cho biểu đồ có trục X là thời gian (Line Chart)
class TimeSeriesChartData {
  TimeSeriesChartData(this.x, this.y);
  final DateTime x;
  final double y;
}

// Dành cho biểu đồ phân loại (Pie Chart, Bar Chart)
class CategoryChartData {
  CategoryChartData(this.category, this.value, {this.quantity});
  final String category;
  final double value;
  final int? quantity; // Thêm nếu cần, ví dụ cho chi tiết sản phẩm
}