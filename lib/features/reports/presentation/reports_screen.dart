import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pharmassist/features/reports/models/report_models.dart';
import 'package:pharmassist/features/reports/providers/reports_providers.dart';
import 'package:pharmassist/features/reports/services/report_pdf_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN');
  final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  // Pagination states for the three tabs
  int _expiryPage = 1;
  int _stockPage = 1;
  int _supplierPage = 1;
  final int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    // Tab length is now 3 (Financial Summary moved out)
    _tabController = TabController(length: 3, vsync: this);
    
    // Reset pagination when tab changes
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _expiryPage = 1;
          _stockPage = 1;
          _supplierPage = 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _exportPdf(FinancialSummaryModel fin, ExpiryAnalyticsModel exp, List<CategoryAnalyticsModel> cats) async {
    try {
      await ReportPdfService.printExecutiveReport(
        financial: fin,
        expiry: exp,
        categories: cats,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<DateTime?> _generateMonthOptions() {
    final now = DateTime.now();
    final List<DateTime?> list = [null]; // null = All Time
    for (int i = 0; i < 12; i++) {
      list.add(DateTime(now.year, now.month - i, 1));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = Colors.grey.withValues(alpha: 0.2);
    
    final financialAsync = ref.watch(financialSummaryProvider);
    final expiryAsync = ref.watch(expiryAnalyticsProvider);
    final categoryAsync = ref.watch(categoryAnalyticsProvider);
    final monthlyTrendsAsync = ref.watch(monthlyTrendsProvider);
    final selectedMonth = ref.watch(selectedMonthFilterProvider);

    final monthOptions = _generateMonthOptions();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Toolbar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.assessment_rounded, color: theme.colorScheme.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reports & Analytics',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Monthly financial metrics, stock movements, and supplier analytics.',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),

                // Month Filter Selector Dropdown
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DateTime?>(
                      value: selectedMonth,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface, fontSize: 13),
                      items: monthOptions.map((date) {
                        final label = date == null ? 'All Time' : DateFormat('MMMM yyyy').format(date);
                        return DropdownMenuItem<DateTime?>(
                          value: date,
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month_rounded, size: 16, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(label),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        ref.read(selectedMonthFilterProvider.notifier).state = val;
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Export PDF Action Button
                FilledButton.icon(
                  onPressed: (financialAsync.hasValue && expiryAsync.hasValue && categoryAsync.hasValue)
                      ? () => _exportPdf(
                          financialAsync.value!,
                          expiryAsync.value!,
                          categoryAsync.value!,
                        )
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('Print Report (PDF)', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 2. Top KPI Cards Row
            financialAsync.when(
              data: (fin) => expiryAsync.when(
                data: (exp) => Row(
                  children: [
                    Expanded(
                      child: _buildKpiCard(
                        title: 'Total Stock',
                        value: currencyFormat.format(fin.totalMrpValue),
                        subtitle: '${fin.totalUnitsCount} Units in Stock',
                        icon: Icons.account_balance_wallet_rounded,
                        color: Colors.teal,
                        theme: theme,
                        borderColor: borderColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard(
                        title: 'Cost Basis (Purchase Value)',
                        value: currencyFormat.format(fin.totalPurchaseValue),
                        subtitle: '${fin.totalMedicinesCount} Unique Medicines',
                        icon: Icons.inventory_2_rounded,
                        color: Colors.blue,
                        theme: theme,
                        borderColor: borderColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard(
                        title: selectedMonth != null
                            ? 'Purchases Spend (${DateFormat('MMM').format(selectedMonth)})'
                            : 'Total Purchase Expenses',
                        value: currencyFormat.format(fin.totalPurchaseExpenses),
                        subtitle: 'Input GST: ${currencyFormat.format(fin.totalGstPaid)}',
                        icon: Icons.shopping_cart_rounded,
                        color: Colors.indigo,
                        theme: theme,
                        borderColor: borderColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard(
                        title: 'Expired Stock Risk',
                        value: currencyFormat.format(exp.expiredStockValue),
                        subtitle: '${exp.expiredBatchesCount} Expired Batches',
                        icon: Icons.warning_rounded,
                        color: Colors.red,
                        theme: theme,
                        borderColor: borderColor,
                      ),
                    ),
                  ],
                ),
                loading: () => const SizedBox(height: 90, child: Center(child: CircularProgressIndicator())),
                error: (err, _) => Text('Error: $err'),
              ),
              loading: () => const SizedBox(height: 90, child: Center(child: CircularProgressIndicator())),
              error: (err, _) => Text('Error: $err'),
            ),

            const SizedBox(height: 12),

            // 3. Financial Summary (Moved out of tabs)
            _buildFinancialSummaryBanner(financialAsync, theme, borderColor),

            const SizedBox(height: 16),

            // 4. Visual Charts Row (3 Charts)
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  // Chart 1: Category Pie Chart
                  Expanded(
                    child: categoryAsync.when(
                      data: (categories) => _buildChartContainer(
                        title: 'Stock Distribution by Category',
                        theme: theme,
                        borderColor: borderColor,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: categories.isEmpty
                                  ? const Center(child: Text('No Data'))
                                  : PieChart(
                                      PieChartData(
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 25,
                                        sections: _buildPieChartSections(categories),
                                      ),
                                      swapAnimationDuration: const Duration(milliseconds: 150),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ListView.builder(
                                itemCount: categories.length,
                                itemBuilder: (context, index) {
                                  final cat = categories[index];
                                  final color = _getCategoryColor(index);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(cat.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11), overflow: TextOverflow.ellipsis),
                                        ),
                                        Text(currencyFormat.format(cat.totalValue), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err')),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Chart 2: Monthly Purchase Trends Bar Chart
                  Expanded(
                    child: monthlyTrendsAsync.when(
                      data: (trends) => _buildChartContainer(
                        title: 'Monthly Purchase Trends (Last 6 Months)',
                        theme: theme,
                        borderColor: borderColor,
                        child: BarChart(
                          BarChartData(
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (val, meta) {
                                    final index = val.toInt();
                                    if (index >= 0 && index < trends.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(trends[index].monthLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                            ),
                            barGroups: List.generate(trends.length, (i) {
                              final trend = trends[i];
                              final isSelected = selectedMonth != null &&
                                  selectedMonth.month == trend.monthDate.month &&
                                  selectedMonth.year == trend.monthDate.year;

                              return BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: trend.purchaseAmount > 0 ? trend.purchaseAmount : 500,
                                    color: isSelected ? theme.colorScheme.primary : Colors.blue.withValues(alpha: 0.5),
                                    width: 16,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              );
                            }),
                          ),
                          swapAnimationDuration: const Duration(milliseconds: 150),
                        ),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err')),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Chart 3: Financial Valuation (MRP vs Cost)
                  Expanded(
                    child: financialAsync.when(
                      data: (fin) => _buildChartContainer(
                        title: 'Stock Valuation Comparison',
                        theme: theme,
                        borderColor: borderColor,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Purchase Cost', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Container(
                                      width: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.7),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(currencyFormat.format(fin.totalPurchaseValue), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Est. MRP Value', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    flex: (fin.totalMrpValue > 0 && fin.totalMrpValue > fin.totalPurchaseValue) ? 2 : 1, // Visual representation
                                    child: Container(
                                      width: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withValues(alpha: 0.7),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(currencyFormat.format(fin.totalMrpValue), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err')),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 5. Tab Navigation Bar
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(text: 'Expiry & Risk Exposure'),
                  Tab(text: 'Stock Movement Audit Log'),
                  Tab(text: 'Supplier Purchases Summary'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 6. Tab Views Area (with Pagination)
            SizedBox(
              height: 540,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildExpiryTab(expiryAsync, theme, borderColor),
                    _buildStockMovementTab(theme, borderColor),
                    _buildSupplierSummaryTab(theme, borderColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required ThemeData theme,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryBanner(AsyncValue<FinancialSummaryModel> finAsync, ThemeData theme, Color borderColor) {
    return finAsync.when(
      data: (fin) {
        final monthText = fin.selectedMonth != null
            ? 'for ${DateFormat('MMMM yyyy').format(fin.selectedMonth!)}'
            : '(All Time)';

        return Row(
          children: [
            Expanded(
              child: _buildDetailMetricCard(
                title: 'Purchase Expenses $monthText',
                value: currencyFormat.format(fin.totalPurchaseExpenses),
                icon: Icons.receipt_long_rounded,
                color: Colors.indigo,
                theme: theme,
                borderColor: borderColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDetailMetricCard(
                title: 'Input GST Tax Paid $monthText',
                value: currencyFormat.format(fin.totalGstPaid),
                icon: Icons.gavel_rounded,
                color: Colors.purple,
                theme: theme,
                borderColor: borderColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDetailMetricCard(
                title: 'Active Batches Registered',
                value: '${fin.totalBatchesCount} Batches',
                icon: Icons.qr_code_2_rounded,
                color: Colors.teal,
                theme: theme,
                borderColor: borderColor,
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildDetailMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartContainer({required String title, required Widget child, required ThemeData theme, required Color borderColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }

  // --- TAB VIEWS WITH PAGINATION ---

  Widget _buildPaginationFooter(int totalItems, int totalPages, int currentPage, Function(int) onPageChanged, ThemeData theme, Color borderColor) {
    if (totalPages <= 1) return const SizedBox.shrink();

    final startIndex = (currentPage - 1) * _rowsPerPage;
    final endIndex = math.min(startIndex + _rowsPerPage, totalItems);

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Text(
            'Showing ${startIndex + 1} to $endIndex of $totalItems entries',
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                color: theme.colorScheme.primary,
                disabledColor: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
              ),
              Text(
                'Page $currentPage of $totalPages',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                color: theme.colorScheme.primary,
                disabledColor: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryTab(AsyncValue<ExpiryAnalyticsModel> expiryAsync, ThemeData theme, Color borderColor) {
    return expiryAsync.when(
      data: (exp) {
        final List<ExpiredBatchItem> items = [...exp.expiredList, ...exp.nearExpiryList];

        if (items.isEmpty) {
          return const Center(child: Text('No expired or near-expiry stock found. Good inventory health!', style: TextStyle(fontWeight: FontWeight.w600)));
        }

        final totalItems = items.length;
        final totalPages = (totalItems / _rowsPerPage).ceil().clamp(1, 99999);
        final startIndex = (_expiryPage - 1) * _rowsPerPage;
        final endIndex = math.min(startIndex + _rowsPerPage, totalItems);
        final paginatedItems = items.sublist(startIndex, endIndex);

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: paginatedItems.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                itemBuilder: (context, index) {
                  final item = paginatedItems[index];
                  final isExpired = item.expiryDate.isBefore(DateTime.now());

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isExpired ? Colors.red : Colors.orange).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isExpired ? Icons.warning_rounded : Icons.timer_rounded,
                        color: isExpired ? Colors.red : Colors.orange,
                        size: 20,
                      ),
                    ),
                    title: Text(item.medicineName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Batch: ${item.batchNo} • Expiry: ${DateFormat('dd MMM yyyy').format(item.expiryDate)} • Qty: ${item.quantity}',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormat.format(item.totalMrpValue),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: isExpired ? Colors.red : Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isExpired ? Colors.red : Colors.orange).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isExpired ? 'EXPIRED' : 'NEAR EXPIRY',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: isExpired ? Colors.red : Colors.orange.shade700),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            _buildPaginationFooter(totalItems, totalPages, _expiryPage, (p) => setState(() => _expiryPage = p), theme, borderColor),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildStockMovementTab(ThemeData theme, Color borderColor) {
    final movementAsync = ref.watch(stockMovementLogsProvider);

    return movementAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(child: Text('No stock adjustment logs found for this period.', style: TextStyle(fontWeight: FontWeight.w600)));
        }

        final totalItems = logs.length;
        final totalPages = (totalItems / _rowsPerPage).ceil().clamp(1, 99999);
        final startIndex = (_stockPage - 1) * _rowsPerPage;
        final endIndex = math.min(startIndex + _rowsPerPage, totalItems);
        final paginatedLogs = logs.sublist(startIndex, endIndex);

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: paginatedLogs.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                itemBuilder: (context, index) {
                  final log = paginatedLogs[index];
                  final isDeduction = log.qtyChange < 0;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isDeduction ? Colors.orange : Colors.green).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDeduction ? Icons.remove_rounded : Icons.add_rounded,
                        color: isDeduction ? Colors.orange.shade700 : Colors.green.shade700,
                        size: 20,
                      ),
                    ),
                    title: Text(log.medicineName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Batch: ${log.batchNo} • Reason: ${log.reason} • ${dateFormat.format(log.date)}',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                      ),
                    ),
                    trailing: Text(
                      '${log.qtyChange > 0 ? "+" : ""}${log.qtyChange}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: isDeduction ? Colors.orange.shade700 : Colors.green.shade700,
                      ),
                    ),
                  );
                },
              ),
            ),
            _buildPaginationFooter(totalItems, totalPages, _stockPage, (p) => setState(() => _stockPage = p), theme, borderColor),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildSupplierSummaryTab(ThemeData theme, Color borderColor) {
    final supplierAsync = ref.watch(supplierSummaryProvider);

    return supplierAsync.when(
      data: (suppliers) {
        if (suppliers.isEmpty) {
          return const Center(child: Text('No supplier purchase entries found for this period.', style: TextStyle(fontWeight: FontWeight.w600)));
        }

        final totalItems = suppliers.length;
        final totalPages = (totalItems / _rowsPerPage).ceil().clamp(1, 99999);
        final startIndex = (_supplierPage - 1) * _rowsPerPage;
        final endIndex = math.min(startIndex + _rowsPerPage, totalItems);
        final paginatedSuppliers = suppliers.sublist(startIndex, endIndex);

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: paginatedSuppliers.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                itemBuilder: (context, index) {
                  final s = paginatedSuppliers[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.local_shipping_rounded, color: theme.colorScheme.primary, size: 20),
                    ),
                    title: Text(s.supplierName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Invoices: ${s.totalInvoices} • Input Tax Paid: ${currencyFormat.format(s.totalTax)}',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                      ),
                    ),
                    trailing: Text(
                      currencyFormat.format(s.totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  );
                },
              ),
            ),
            _buildPaginationFooter(totalItems, totalPages, _supplierPage, (p) => setState(() => _supplierPage = p), theme, borderColor),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(List<CategoryAnalyticsModel> categories) {
    final totalVal = categories.fold<double>(0.0, (sum, c) => sum + c.totalValue);
    if (totalVal <= 0) return [];

    return List.generate(categories.length, (i) {
      final cat = categories[i];
      final pct = (cat.totalValue / totalVal) * 100;
      final color = _getCategoryColor(i);

      return PieChartSectionData(
        color: color,
        value: cat.totalValue,
        title: '${pct.toStringAsFixed(0)}%',
        radius: 30,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
      );
    });
  }

  Color _getCategoryColor(int index) {
    final colors = [
      Colors.teal,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
    ];
    return colors[index % colors.length];
  }
}