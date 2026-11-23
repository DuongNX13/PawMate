import 'package:flutter/material.dart';

enum HealthKnowledgeFilter {
  all('Tất cả'),
  prevention('Phòng ngừa'),
  nutrition('Dinh dưỡng'),
  emergency('Cấp cứu');

  const HealthKnowledgeFilter(this.label);

  final String label;
}

class HealthKnowledgeArticle {
  const HealthKnowledgeArticle({
    required this.id,
    required this.filter,
    required this.eyebrow,
    required this.title,
    required this.summary,
    required this.icon,
  });

  final String id;
  final HealthKnowledgeFilter filter;
  final String eyebrow;
  final String title;
  final String summary;
  final IconData icon;
}

const bundledHealthKnowledge = <HealthKnowledgeArticle>[
  HealthKnowledgeArticle(
    id: 'hypothermia-first-aid',
    filter: HealthKnowledgeFilter.emergency,
    eyebrow: 'CẤP CỨU',
    title: 'Dấu hiệu hạ thân nhiệt và cách xử lý ban đầu',
    summary: 'Giữ ấm an toàn và đưa thú cưng tới cơ sở thú y sớm nhất.',
    icon: Icons.emergency_outlined,
  ),
  HealthKnowledgeArticle(
    id: 'vaccination-checklist',
    filter: HealthKnowledgeFilter.prevention,
    eyebrow: 'PHÒNG NGỪA',
    title: 'Checklist tiêm phòng theo từng giai đoạn',
    summary: 'Theo dõi mũi cơ bản, mũi nhắc và lịch tái khám cùng bác sĩ.',
    icon: Icons.vaccines_outlined,
  ),
  HealthKnowledgeArticle(
    id: 'healthy-weight',
    filter: HealthKnowledgeFilter.nutrition,
    eyebrow: 'DINH DƯỠNG',
    title: 'Duy trì cân nặng khỏe mạnh cho thú cưng',
    summary: 'Kết hợp khẩu phần phù hợp với vận động và theo dõi định kỳ.',
    icon: Icons.monitor_weight_outlined,
  ),
];
