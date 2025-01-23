import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webfeed/webfeed.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';

class NewsItem {
  final String title;
  final String description;
  final String link;
  final String? imageUrl;
  final DateTime? pubDate;

  NewsItem({
    required this.title,
    required this.description,
    required this.link,
    this.imageUrl,
    this.pubDate,
  });
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<NewsItem> _news = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  String _decodeText(String text) {
    try {
      // First try UTF-8
      return utf8.decode(text.runes.toList());
    } catch (e) {
      try {
        // If UTF-8 fails, try Big5 (commonly used in Traditional Chinese)
        return const Big5Decoder().convert(text.codeUnits);
      } catch (e) {
        // If both fail, return the original text
        return text;
      }
    }
  }

  Future<void> _fetchNews() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.td.gov.hk/tc/special_news/spnews_rss.xml'),
        headers: {
          'Accept-Charset': 'UTF-8',
        },
      );

      if (response.statusCode == 200) {
        // Decode the response body properly
        String decodedBody = utf8.decode(response.bodyBytes);
        
        final feed = RssFeed.parse(decodedBody);
        setState(() {
          _news = feed.items?.map((item) {
                // Extract image URL from description if available
                String? imageUrl;
                if (item.description != null) {
                  final imgRegExp = RegExp(r'<img[^>]+src="([^">]+)"');
                  final match = imgRegExp.firstMatch(item.description!);
                  if (match != null) {
                    imageUrl = match.group(1);
                  }
                }

                // Decode title and description
                String decodedTitle = _decodeText(item.title ?? 'No title');
                String decodedDescription = _decodeText(
                  item.description?.replaceAll(RegExp(r'<[^>]*>'), '') ?? 'No description'
                );

                return NewsItem(
                  title: decodedTitle,
                  description: decodedDescription,
                  link: item.link ?? '',
                  imageUrl: imageUrl,
                  pubDate: item.pubDate,
                );
              }).toList() ??
              [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load news: $e';
        _isLoading = false;
      });
    }
  }

  void _showNewsDetail(NewsItem news) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(news.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (news.imageUrl != null)
                  CachedNetworkImage(
                    imageUrl: news.imageUrl!,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                const SizedBox(height: 16),
                Text(news.description),
                const SizedBox(height: 16),
                if (news.pubDate != null)
                  Text(
                    'Published: ${news.pubDate!.toString().split('.')[0]}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                final url = Uri.parse(news.link);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: const Text('Open in Browser'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _refreshNews() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    await _fetchNews();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error),
            ElevatedButton(
              onPressed: _refreshNews,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshNews,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: _news.length,
          itemBuilder: (context, index) {
            final news = _news[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () => _showNewsDetail(news),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (news.imageUrl != null)
                      CachedNetworkImage(
                        imageUrl: news.imageUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 180,
                          color: Colors.grey[300],
                          child: Center(
                            child: Icon(
                              Icons.image,
                              size: 50,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 180,
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.error),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            news.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (news.pubDate != null)
                            Row(
                              children: [
                                Icon(Icons.access_time,
                                    size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  news.pubDate!.toString().split('.')[0],
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class Big5Decoder extends Converter<List<int>, String> {
  const Big5Decoder();

  @override
  String convert(List<int> input) {
    return String.fromCharCodes(input);
  }
}