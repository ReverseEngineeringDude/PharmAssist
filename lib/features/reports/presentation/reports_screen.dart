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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    final financialAsync = ref.watch(financialSummaryProvider);
    final expiryAsync = ref.watch(expiryAnalyticsProvider);
    final categoryAsync = ref.watch(categoryAnalyticsProvider);
    final monthlyTrendsAsync = ref.watch(monthlyTrendsProvider);
    final selectedMonth = ref.watch(selectedMonthFilterProvider);

    final monthOptions = _generateMonthOptions();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Toolbar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reports & Analytics',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Monthly financial metrics, stock movements, and supplier analytics.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
                      ),
                    ],
                  ),
                ),

                // Month Filter Selector Dropdown
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DateTime?>(
                      value: selectedMonth,
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 13),
                      items: monthOptions.map((date) {
                        final label = date == null
                            ? '📅 All Time'
                            : '📅 ${DateFormat('MMMM yyyy').format(date)}';
                        return DropdownMenuItem<DateTime?>(
                          value: date,
                          child: Text(label),
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
                ElevatedButton.icon(
                  onPressed: (financialAsync.hasValue && expiryAsync.hasValue && categoryAsync.hasValue)
                      ? () => _exportPdf(
                            financialAsync.value!,
                            expiryAsync.value!,
                            categoryAsync.value!,
                          )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('Print Report (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Top KPI Cards Row
            financialAsync.when(
              data: (fin) => expiryAsync.when(
                data: (exp) => Row(
                  children: [
                    Expanded(
                      child: _buildKpiCard(
                        title: 'Total Stock Valuation (MRP)',
                        value: currencyFormat.format(fin.totalMrpValue),
                        subtitle: '${fin.totalUnitsCount} Units in Stock',
                        icon: Icons.account_balance_wallet_rounded,
                        color: Colors.teal,
                        theme: theme,
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
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard(
                        title: 'Expired Stock Risk',
                        value: currencyFormat.format(exp.expiredStockValue),
                        subtitle: '${exp.expiredBatchesCount} Expired Batches',
                        icon: Icons.warning_amber_rounded,
                        color: Colors.red,
                        theme: theme,
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

            const SizedBox(height: 16),

            // Visual Charts Row (Category Pie Chart + Monthly Trends Bar Chart)
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  // Category Pie Chart
                  Expanded(
                    flex: 5,
                    child: categoryAsync.when(
                      data: (categories) => Card(
                        elevation: 0,
                        color: theme.colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: theme.dividerColor),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 140,
                                child: categories.isEmpty
                                    ? const Center(child: Text('No Data'))
                                    : PieChart(
                                        PieChartData(
                                          sectionsSpace: 2,
                                          centerSpaceRadius: 30,
                                          sections: _buildPieChartSections(categories),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Stock Distribution by Category',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 6),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: categories.length,
                                        itemBuilder: (context, index) {
                                          final cat = categories[index];
                                          final color = _getCategoryColor(index);
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Row(
                                              children: [
                                                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                                const SizedBox(width: 6),
                                                Text(cat.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                                                const Spacer(),
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
                            ],
                          ),
                        ),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err')),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Monthly Purchase Trends Bar Chart
                  Expanded(
                    flex: 5,
                    child: monthlyTrendsAsync.when(
                      data: (trends) => Card(
                        elevation: 0,
                        color: theme.colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: theme.dividerColor),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Monthly Purchase Expenses Trend (Last 6 Months)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
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
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(trends[index].monthLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
                                            color: isSelected ? theme.colorScheme.primary : Colors.teal.withValues(alpha: 0.6),
                                            width: 18,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ],
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err')),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tab Navigation Bar
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.disabledColor,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: const [
                  Tab(text: 'Financial Summary'),
                  Tab(text: 'Expiry & Risk Exposure'),
                  Tab(text: 'Stock Movement Audit Log'),
                  Tab(text: 'Supplier Purchases Summary'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tab Views Area
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFinancialTab(financialAsync, theme),
                  _buildExpiryTab(expiryAsync, theme),
                  _buildStockMovementTab(theme),
                  _buildSupplierSummaryTab(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, color: theme.disabledColor, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: theme.textTheme.bodyLarge?.color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialTab(AsyncValue<FinancialSummaryModel> finAsync, ThemeData theme) {
    return finAsync.when(
      data: (fin) {
        final monthText = fin.selectedMonth != null
            ? 'for ${DateFormat('MMMM yyyy').format(fin.selectedMonth!)}'
            : '(All Time)';

        return SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDetailMetricCard(
                      title: 'Purchase Expenses $monthText',
                      value: currencyFormat.format(fin.totalPurchaseExpenses),
                      icon: Icons.receipt_long_rounded,
                      color: Colors.indigo,
                      theme: theme,
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
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildDetailMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: theme.disabledColor)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryTab(AsyncValue<ExpiryAnalyticsModel> expiryAsync, ThemeData theme) {
    return expiryAsync.when(
      data: (exp) {
        final List<ExpiredBatchItem> items = [...exp.expiredList, ...exp.nearExpiryList];

        if (items.isEmpty) {
          return const Center(child: Text('No expired or near-expiry stock found. Good inventory health!'));
        }

        return Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
            itemBuilder: (context, index) {
              final item = items[index];
              final isExpired = item.expiryDate.isBefore(DateTime.now());

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: (isExpired ? Colors.red : Colors.orange).withValues(alpha: 0.12),
                  child: Icon(
                    isExpired ? Icons.warning_rounded : Icons.timer_rounded,
                    color: isExpired ? Colors.red : Colors.orange,
                  ),
                ),
                title: Text(item.medicineName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(
                  'Batch: ${item.batchNo} • Expiry: ${DateFormat('dd MMM yyyy').format(item.expiryDate)} • Qty: ${item.quantity}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(item.totalMrpValue),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isExpired ? Colors.red : Colors.orange,
                      ),
                    ),
                    Text(
                      isExpired ? 'EXPIRED' : 'Near Expiry',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isExpired ? Colors.red : Colors.orange),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildStockMovementTab(ThemeData theme) {
    final movementAsync = ref.watch(stockMovementLogsProvider);

    return movementAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(child: Text('No stock adjustment logs found for this period.'));
        }

        return Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: ListView.separated(
            itemCount: logs.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
            itemBuilder: (context, index) {
              final log = logs[index];
              final isDeduction = log.qtyChange < 0;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: (isDeduction ? Colors.orange : Colors.green).withValues(alpha: 0.12),
                  child: Icon(
                    isDeduction ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
                    color: isDeduction ? Colors.orange : Colors.green,
                  ),
                ),
                title: Text(log.medicineName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(
                  'Batch: ${log.batchNo} • Reason: ${log.reason} • ${dateFormat.format(log.date)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  '${log.qtyChange > 0 ? "+" : ""}${log.qtyChange}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: isDeduction ? Colors.orange : Colors.green,
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildSupplierSummaryTab(ThemeData theme) {
    final supplierAsync = ref.watch(supplierSummaryProvider);

    return supplierAsync.when(
      data: (suppliers) {
        if (suppliers.isEmpty) {
          return const Center(child: Text('No supplier purchase entries found for this period.'));
        }

        return Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: ListView.separated(
            itemCount: suppliers.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
            itemBuilder: (context, index) {
              final s = suppliers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.local_shipping_rounded, color: theme.colorScheme.primary),
                ),
                title: Text(s.supplierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('Invoices: ${s.totalInvoices} • Input Tax Paid: ${currencyFormat.format(s.totalTax)}', style: const TextStyle(fontSize: 12)),
                trailing: Text(
                  currencyFormat.format(s.totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              );
            },
          ),
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
        radius: 35,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
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
