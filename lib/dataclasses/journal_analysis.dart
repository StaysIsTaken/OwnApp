import 'package:flutter/material.dart';

class JournalAnalysis {
  final String id;
  final String journalEntryId;
  final double? sentimentScore;
  final String? sentimentLabel;
  final List<String> detectedTopics;
  final String? summary;
  final String? rawAnalysis;
  final DateTime createdAt;

  JournalAnalysis({
    required this.id,
    required this.journalEntryId,
    this.sentimentScore,
    this.sentimentLabel,
    this.detectedTopics = const [],
    this.summary,
    this.rawAnalysis,
    required this.createdAt,
  });

  factory JournalAnalysis.fromJson(Map<String, dynamic> json) {
    List<String> topics = [];
    if (json['detectedTopics'] != null) {
      if (json['detectedTopics'] is String) {
        topics = (json['detectedTopics'] as String)
            .replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll('"', '')
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();
      } else if (json['detectedTopics'] is List) {
        topics = List<String>.from(json['detectedTopics']);
      }
    }

    return JournalAnalysis(
      id: json['id'] ?? '',
      journalEntryId: json['journalEntryId'] ?? '',
      sentimentScore: json['sentimentScore'] != null
          ? double.tryParse(json['sentimentScore'].toString())
          : null,
      sentimentLabel: json['sentimentLabel'],
      detectedTopics: topics,
      summary: json['summary'],
      rawAnalysis: json['rawAnalysis'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'journalEntryId': journalEntryId,
      'sentimentScore': sentimentScore,
      'sentimentLabel': sentimentLabel,
      'detectedTopics': detectedTopics,
      'summary': summary,
      'rawAnalysis': rawAnalysis,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Color getSentimentColor() {
    if (sentimentScore == null) return Colors.grey;
    if (sentimentScore! > 0.3) return Colors.green;
    if (sentimentScore! < -0.3) return Colors.red;
    return Colors.grey;
  }

  String getSentimentEmoji() {
    if (sentimentScore == null) return '😐';
    if (sentimentScore! > 0.5) return '😊';
    if (sentimentScore! > 0.2) return '🙂';
    if (sentimentScore! > -0.2) return '😐';
    if (sentimentScore! > -0.5) return '😕';
    return '😢';
  }

  String getSentimentText() {
    return sentimentLabel ?? 'Neutral';
  }
}
