import 'package:flutter/material.dart';

class UserGuideScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Hướng dẫn sử dụng",
          style: TextStyle(color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white), // Nút quay lại màu trắng
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Chào mừng bạn đến với ứng dụng!"),
            _buildSectionContent(
              "Ứng dụng này giúp bạn quản lý tài chính cá nhân, bao gồm doanh thu, chi phí, và sản phẩm/dịch vụ. Dưới đây là hướng dẫn cơ bản để bắt đầu:",
            ),
            const SizedBox(height: 16),
            _buildSectionTitle("1. Quản lý doanh thu"),
            _buildSectionContent(
              "- Chọn ngày để ghi nhận doanh thu.\n"
                  "- Nhập doanh thu chính, phụ, hoặc khác trong phần 'Doanh thu'.\n"
                  "- Xem lịch sử giao dịch để theo dõi chi tiết.",
            ),
            const SizedBox(height: 16),
            _buildSectionTitle("2. Quản lý chi phí"),
            _buildSectionContent(
              "- Thêm chi phí cố định (như tiền thuê) hoặc chi phí biến đổi (như điện nước).\n"
                  "- Sử dụng danh sách chi phí để theo dõi và chỉnh sửa.",
            ),
            const SizedBox(height: 16),
            _buildSectionTitle("3. Quản lý sản phẩm/dịch vụ"),
            _buildSectionContent(
              "- Vào màn hình 'Sản phẩm/Dịch vụ' để thêm, chỉnh sửa hoặc xóa sản phẩm.\n"
                  "- Chọn danh mục 'Chính' hoặc 'Phụ' để quản lý riêng biệt.",
            ),
            const SizedBox(height: 16),
            _buildSectionTitle("4. Xem báo cáo"),
            _buildSectionContent(
              "- Sử dụng các báo cáo để phân tích doanh thu, chi phí, và lợi nhuận theo ngày hoặc khoảng thời gian.\n"
                  "- Kiểm tra tỷ lệ lợi nhuận và chi phí để tối ưu hóa tài chính.",
            ),
            const SizedBox(height: 16),
            _buildSectionTitle("Cần hỗ trợ thêm?"),
            _buildSectionContent(
              "Liên hệ với chúng tôi qua email: support@example.com\n"
                  "Hoặc truy cập trang web của chúng tôi để xem thêm tài liệu.",
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                // Mở liên kết đến điều khoản sử dụng (nếu cần)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Điều khoản sử dụng đang được cập nhật")),
                );
              },
              child: const Text(
                "Xem Điều khoản sử dụng",
                style: TextStyle(
                  color: Color(0xFF1976D2),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1976D2), // Đồng bộ với màu chính
      ),
    );
  }

  Widget _buildSectionContent(String content) {
    return Text(
      content,
      style: const TextStyle(fontSize: 16, height: 1.5), // Giữ màu mặc định của theme
    );
  }
}