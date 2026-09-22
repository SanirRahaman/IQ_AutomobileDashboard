import 'dart:convert';

Map<String, Object?> canonicalDatasetMap() => {
      'metadata': {
        'generated_at': '2025-08-01T00:00:00Z',
        'description': 'Fixture',
        'date_range': 'July 2025',
        'notes': 'Synthetic',
      },
      'branches': [
        {'id': 'B1', 'name': 'Central', 'city': 'Chennai'},
      ],
      'sales_reps': [
        {
          'id': 'SR1',
          'name': 'Representative',
          'branch_id': 'B1',
          'role': 'sales_officer',
          'joined': '2024-01-10',
        },
      ],
      'leads': [
        {
          'id': 'L1',
          'customer_name': 'Customer',
          'phone': '0000000000',
          'source': null,
          'model_interested': 'Model',
          'status': 'contacted',
          'assigned_to': 'SR1',
          'branch_id': 'B1',
          'created_at': '2025-07-01T09:00:00Z',
          'last_activity_at': '2025-07-02T09:00:00Z',
          'status_history': [
            {
              'status': 'new',
              'timestamp': '2025-07-01T09:00:00Z',
              'note': null,
            },
            {
              'status': 'contacted',
              'timestamp': '2025-07-02T09:00:00Z',
              'note': 'Contact made',
            },
          ],
          'expected_close_date': '2025-07-20',
          'deal_value': 1000,
          'lost_reason': null,
        },
      ],
      'targets': [
        {
          'branch_id': 'B1',
          'month': '2025-07',
          'target_units': 5,
          'target_revenue': 5000,
        },
      ],
      'deliveries': <Object?>[],
    };

String canonicalDatasetJson() => jsonEncode(canonicalDatasetMap());
