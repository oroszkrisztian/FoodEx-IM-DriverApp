import 'package:flutter/material.dart';
import 'package:foodex/globals.dart';
import 'package:intl/intl.dart';

class ExpenseFilterContainer extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> expenseTypes;
  final String selectedType;
  final VoidCallback onSelectStartDate;
  final VoidCallback onSelectEndDate;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback onApplyFilters;
  final bool isLoadingTypes;

  const ExpenseFilterContainer({
    super.key,
    this.startDate,
    this.endDate,
    required this.expenseTypes,
    required this.selectedType,
    required this.onSelectStartDate,
    required this.onSelectEndDate,
    required this.onTypeChanged,
    required this.onApplyFilters,
    this.isLoadingTypes = false,
  });

  @override
  State<ExpenseFilterContainer> createState() => _ExpenseFilterContainerState();
}

class _ExpenseFilterContainerState extends State<ExpenseFilterContainer> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        setState(() {
          isExpanded = !isExpanded;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            width: 1,
            color: Colors.grey[300]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${Globals.getText('logsApply')}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 1, 160, 226),
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color.fromARGB(255, 1, 160, 226),
                  ),
                ],
              ),
            ),

            // Expandable Content
            if (isExpanded) ...[
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Selection Row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              widget.startDate == null
                                  ? '${Globals.getText('logsFrom')}'
                                  : DateFormat('yyyy-MM-dd')
                                      .format(widget.startDate!),
                            ),
                            onPressed: widget.onSelectStartDate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              widget.endDate == null
                                  ? '${Globals.getText('logsTo')}'
                                  : DateFormat('yyyy-MM-dd')
                                      .format(widget.endDate!),
                            ),
                            onPressed: widget.onSelectEndDate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Expense Type Selection
                    Text(
                      '${Globals.getText('vehicleDataType')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                        color: Colors.white,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: widget.isLoadingTypes
                          ? const Center(
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color.fromARGB(255, 1, 160, 226),
                                  ),
                                ),
                              ),
                            )
                          : DropdownButton<String>(
                              value: widget.selectedType,
                              isExpanded: true,
                              underline: Container(),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Color.fromARGB(255, 1, 160, 226),
                              ),
                              onChanged: widget.onTypeChanged,
                              items: widget.expenseTypes
                                  .map<DropdownMenuItem<String>>((String type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(
                                    type,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Apply Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onApplyFilters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 1, 160, 226),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: Text(
                          '${Globals.getText('logsApply')}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}