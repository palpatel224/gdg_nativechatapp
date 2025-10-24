import 'package:flutter/material.dart';
import '../../pages/home/user_list_screen.dart';
import '../../pages/profile/profile_edit_page.dart';
import '../../repositories/auth_repository.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final IAuthRepository? authRepository;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.authRepository,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: Container(
        width: screenWidth * 0.5, // 50% of screen width for 3 items
        height: 70,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Chat icon - Navigate to HomePage (no navigation needed, just update index)
            _buildNavItem(
              icon: Icons.chat_bubble_outline,
              isSelected: currentIndex == 0,
              onTap: () {
                onTap(0);
                // HomePage is always shown in MainPage, just update the tab
              },
            ),
            // People icon - Navigate to UserListScreen
            _buildNavItem(
              icon: Icons.people_outline,
              isSelected: currentIndex == 1,
              onTap: () {
                onTap(1);
                // Navigate directly to UserListScreen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const UserListScreen(),
                  ),
                );
              },
            ),
            // Profile icon - Navigate to ProfileEditPage
            _buildNavItem(
              icon: Icons.person_outline,
              isSelected: currentIndex == 2,
              onTap: () {
                onTap(2);
                // Navigate to ProfileEditPage
                if (authRepository != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfileEditPage(repo: authRepository!),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white54,
          size: 28,
        ),
      ),
    );
  }
}
