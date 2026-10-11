import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/company_model.dart';
import '../../screens/company_details_screen.dart';

class CompanySidebar extends StatelessWidget {
  final List<Company> companies;
  final String? selectedCompanyId;
  final Function(String) onCompanySelected;
  final VoidCallback onAddCompany;

  const CompanySidebar({
    super.key,
    required this.companies,
    required this.selectedCompanyId,
    required this.onCompanySelected,
    required this.onAddCompany,
    this.unreadCounts = const {},
  });

  final Map<String, int> unreadCounts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        // Glassmorphic sidebar: translucent instead of flat solid
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Home / DM Button
          _buildSidebarItem(
            icon: Icons.home,
            isSelected: selectedCompanyId == null,
            onTap: () => onCompanySelected('dm'),
          ),
          const SizedBox(height: 8),
          Divider(
            color: Colors.white.withValues(alpha: 0.1),
            indent: 16,
            endIndent: 16,
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView.separated(
              itemCount: companies.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final company = companies[index];
                return _buildCompanyItem(context, company);
              },
            ),
          ),

          const SizedBox(height: 8),
          _buildSidebarItem(
            icon: Icons.add,
            isSelected: false,
            onTap: onAddCompany,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCompanyItem(BuildContext context, Company company) {
    bool isSelected = company.id == selectedCompanyId;
    return GestureDetector(
      onTap: () {
        if (isSelected) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CompanyDetailsScreen(company: company),
            ),
          );
        } else {
          onCompanySelected(company.id);
        }
      },
      child: Row(
        children: [
          // Selection Indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 4,
            height: isSelected ? 40 : 8,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accentBlue : Colors.transparent,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
          ),
          // Icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.06),
              shape: isSelected ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isSelected ? BorderRadius.circular(16) : null,
              border: Border.all(
                color: isSelected
                    ? AppColors.accentBlue.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
              image: company.iconUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(company.iconUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.accentBlue.withValues(alpha: 0.2),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (company.iconUrl.isEmpty)
                  Center(
                    child: Text(
                      company.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                // Notification Badge
                if (unreadCounts[company.id] != null &&
                    unreadCounts[company.id]! > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.deepNavy,
                          width: 2,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '${unreadCounts[company.id]}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 4,
            height: isSelected ? 40 : 8,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accentBlue : Colors.transparent,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accentBlue.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
              shape: isSelected ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isSelected ? BorderRadius.circular(16) : null,
              border: Border.all(
                color: isSelected
                    ? AppColors.accentBlue.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.accentBlue.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon, color: AppColors.white, size: 22),
          ),
        ],
      ),
    );
  }
}
