import 'package:flutter/material.dart';

import 'storefront_page.dart';

/// Public storefront web app. The shop is chosen by the URL:
///   `https://host/slug`         (path)   e.g. /aungset-3f9a
///   `https://host/?shop=slug`   (query)  fallback for local dev
class StorefrontApp extends StatelessWidget {
  const StorefrontApp({super.key});

  String get _slug {
    final uri = Uri.base;
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first.isNotEmpty) {
      return uri.pathSegments.first;
    }
    return uri.queryParameters['shop'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final slug = _slug;
    return MaterialApp(
      title: 'Shop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C4AB6),
        useMaterial3: true,
      ),
      home: slug.isEmpty
          ? const _NoSlug()
          : StorefrontPage(slug: slug),
    );
  }
}

class _NoSlug extends StatelessWidget {
  const _NoSlug();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Open a shop link, e.g. /your-shop-slug',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
