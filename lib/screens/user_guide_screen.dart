import 'package:flutter/material.dart';

// Để sử dụng chức năng mở email hoặc link, bạn cần thêm package url_launcher vào file pubspec.yaml
// import 'package:url_launcher/url_launcher.dart';

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // UPDATED: Lấy theme hiện tại của ứng dụng
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // NOTE: AppBar với màu gradient thương hiệu thường được giữ nguyên ở cả 2 chế độ
    // để duy trì nhận diện. Nếu muốn thay đổi, bạn có thể tạo một gradient khác cho dark mode.
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
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // UPDATED: Body sẽ tự động có màu nền theo theme (sáng hoặc tối)
      body: ListView(
        padding: const EdgeInsets.all(12.0),
        children: [
          _buildWelcomeSection(context), // Pass context
          const SizedBox(height: 8),

          // Tất cả các section bây giờ đều được truyền 'context' để có thể tự cập nhật màu sắc
          _buildGuideSection(
            context: context,
            title: "1. Quản lý danh sách sản phẩm/dịch vụ",
            icon: Icons.inventory_2_outlined,
            children: [
              _buildStep(context, "Bước 1", "Trong màn hình chính của ứng dụng, chọn mục Sản phẩm."),
              _buildStep(context, "Bước 2 & 3", "Nhập lần lượt tên sản phẩm/ dịch vụ và giá tiền bán ra trên mỗi đơn vị."),
              _buildStep(context, "Bước 4", "Nhấn Thêm sản phẩm, lúc này ở bên tab danh sách sẽ xuất hiện sản phẩm mà bạn vừa thêm."),
              _buildGuideImage('assets/images/product_service_screen.jpg'),
              _buildNoteWidget(context,
                  "Ở đây sẽ có 2 khoản mục doanh thu gồm doanh thu chính và doanh thu phụ:\n- Doanh thu chính là những khoản thu đến từ các sản phẩm hoặc dịch vụ cốt lõi.\n- Doanh thu phụ là các khoản thu bổ sung – đến từ những mặt hàng bán kèm, không phải trọng tâm\nBạn hãy chọn sản phẩm tương ứng với loại doanh thu nhé."),
            ],
          ),

          _buildGuideSection(
            context: context,
            title: "2. Hướng dẫn thêm Giá vốn/Chi phí biến đổi",
            icon: Icons.attach_money_outlined,
            children: [
              _buildInfoWidget(context, "Giá vốn/Chi phí biến đổi là khoản chi phí trực tiếp phát sinh khi tạo ra một đơn vị sản phẩm hoặc cung cấp một dịch vụ (ví dụ: nguyên vật liệu, chi phí gia công). Chúng được sử dụng để tính lợi nhuận gộp và phân tích hiệu quả từng sản phẩm."),
              _buildStep(context, "Bước 1", "Ở màn hình chi phí, bấm vào mục DS Biến đổi."),
              _buildStep(context, "Bước 2", "Nhập lần lượt tên chi phí, số tiền (theo % hoặc số tiền chính xác), và gắn sản phẩm tương ứng mà chúng ta đã thêm truớc đó."),
              _buildStep(context, "Bước 3", "Nhấn Lưu danh sách. Lúc này chi phí cấu thành nên sản phẩm/dịch vụ tương ứng đã được thêm vào."),
              _buildGuideImage('assets/images/expense_list.jpg'),
            ],
          ),

          _buildGuideSection(
            context: context,
            title: "3. Ghi nhận doanh thu",
            icon: Icons.point_of_sale_outlined,
            children: [
              _buildStep(context, "Bước 1", "Ở màn hình doanh thu của ứng dụng, bạn nhấn vào mục Chính hoặc Phụ tùy vào loại doanh thu muốn ghi nhận."),
              _buildStep(context, "Bước 2", "Chọn sản phẩm bạn đã thêm, ứng dụng sẽ tự động điền giá bán, chi phí biến đổi và lợi nhuận gộp theo sản phẩm."),
              _buildStep(context, "Bước 3", "Nhấn thêm giao dịch, lịch sử giao dịch sẽ được xuất hiện ở bên tab lịch sử hoặc ở ngoài màn hình doanh thu."),
              _buildGuideImage('assets/images/revenue_record.jpg'),
            ],
          ),

          _buildGuideSection(
            context: context,
            title: "4. Hướng dẫn ghi nhận chi phí cố định",
            icon: Icons.home_work_outlined,
            children: [
              _buildStep(context, "Bước 1", "Ở màn hình chi phí của ứng dụng, các bạn nhấn vào mục CĐ Tháng."),
              _buildStep(context, "Bước 2", "Chọn tháng và các ngày trong tháng (mặc định là tất cả các ngày) bạn muốn chia đều chi phí cố định."),
              _buildStep(context, "Bước 3", "Nhập tên khoản mục chi phí cố định (Ví dụ: Thuê mặt bằng)."),
              _buildStep(context, "Bước 4", "Nhập số tiền và nhấn ✅. Lúc này số tiền chi phí cố định của tháng sẽ được chia đều cho tất cả các ngày trong tháng đó."),
            ],
          ),

          _buildGuideSection(
            context: context,
            title: "5. Hướng dẫn sử dụng A.I phân tích",
            icon: Icons.auto_awesome_outlined,
            children: [
              _buildStep(context, "Bước 1", "Vào màn hình khuyến nghị của ứng dụng."),
              _buildStep(context, "Bước 2", "Nhập ngành nghề bạn đang kinh doanh (Ví dụ: quán cà phê, tiệm tóc, v.v)."),
              _buildStep(context, "Bước 3", "Chọn khoảng thời gian bạn muốn phân tích (mặc định 7 ngày gần nhất)."),
              _buildStep(context, "Bước 4", "Nhấn nhận phân tích từ A.I và đợi một lúc, A.I sẽ trả về kết quả phân tích từ dữ liệu kinh doanh của bạn."),
              _buildGuideImage('assets/images/AI_function.jpg'),
            ],
          ),

          _buildGuideSection(
            context: context,
            title: "6. Hướng dẫn sử dụng chức năng phân quyền",
            icon: Icons.people_alt_outlined,
            children: [
              _buildStep(context, "Bước 1", "Nhấn vào phần avatar người dùng để vào màn hình cài đặt."),
              _buildStep(context, "Bước 2", "Ở màn hình cài đặt, nhấn vào mục quản lý quyền truy cập."),
              _buildStep(context, "Bước 3", "Sau đó nhấn vào Thêm cộng tác viên và nhập email của người bạn muốn phân quyền."),
              _buildStep(context, "Bước 4", "Sau khi phân quyền hãy nhấn vào người dùng vừa thêm và phân quyền chi tiết cho người dùng đó."),
              _buildGuideImage('assets/images/permission.png'),
            ],
          ),

          const SizedBox(height: 24),
          _buildSupportSection(context),
        ],
      ),
    );
  }

  // --- WIDGETS HỖ TRỢ ---

  Widget _buildWelcomeSection(BuildContext context) {
    // NEW: Kiểm tra dark mode để chọn màu phù hợp
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? Colors.lightBlueAccent[200]! : const Color(0xFF1976D2);

    return Card(
      // Card sẽ tự động đổi màu nền theo theme
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Chào mừng bạn đến với Finivo!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryColor, // UPDATED: Dùng màu động
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Ứng dụng hỗ trợ quản lý tài chính kinh doanh bán chuyên theo hướng kế toán quản trị, bao gồm doanh thu, chi phí và sản phẩm/dịch vụ, v.v.",
              // Chữ này sẽ tự đổi màu theo theme chính
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideSection({
    required BuildContext context, // NEW: Thêm context
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? Colors.lightBlueAccent[200]! : const Color(0xFF1976D2);
    final titleColor = isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black87;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icon, color: primaryColor), // UPDATED: Dùng màu động
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: titleColor, // UPDATED: Dùng màu động
          ),
        ),
        childrenPadding:
        const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        children: children,
      ),
    );
  }

  Widget _buildStep(BuildContext context, String stepTitle, String content) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final stepTitleColor = isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black87;

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$stepTitle: ",
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.bold,
              color: stepTitleColor, // UPDATED: Dùng màu động
            ),
          ),
          Expanded(
            child: Text(
              content,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteWidget(BuildContext context, String text) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.lightBlueAccent[200]! : const Color(0xFF1976D2);
    final backgroundColor = isDarkMode ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.1);
    final textColor = isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor, // UPDATED
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: baseColor.withOpacity(0.5)), // UPDATED
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline,
              color: baseColor, size: 20), // UPDATED
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 15, height: 1.4, color: textColor), // UPDATED
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoWidget(BuildContext context, String text) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1);
    final iconColor = isDarkMode ? Colors.grey[400]! : Colors.grey.shade700;
    final textColor = isDarkMode ? Colors.grey[300]! : Colors.grey.shade800;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor, // UPDATED
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: iconColor, size: 20), // UPDATED
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 15, height: 1.4, color: textColor), // UPDATED
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideImage(String imageName) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(imageName),
      ),
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? Colors.lightBlueAccent[200]! : const Color(0xFF1976D2);

    return Card(
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.email_outlined, color: primaryColor), // UPDATED
            title: const Text("Cần hỗ trợ thêm?"),
            subtitle: const Text("Liên hệ với chúng tôi qua email: locamapper@gmail.com"),
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Chức năng đang được phát triển")),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.description_outlined, color: primaryColor), // UPDATED
            title: const Text("Xem Điều khoản sử dụng"),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Điều khoản sử dụng đang được cập nhật")),
              );
            },
          ),
        ],
      ),
    );
  }
}