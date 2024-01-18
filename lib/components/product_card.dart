import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:swiftlead/shared/theme.dart';
import 'package:intl/intl.dart';

class ProductCard extends StatelessWidget {
  final String title;
  final String description;
  final int price;
  final String storageUrl;
  final String imagePath;

  const ProductCard({
    super.key,
    required this.title,
    required this.description,
    required this.price,
    required this.storageUrl,
    required this.imagePath,
  });

  String formatPrice(int price) {
    final formatter = NumberFormat("#,##0", "id_ID");
    return 'Rp${formatter.format(price)}';
  }

  Future<String> getDownloadUrl() async {
    try {
      Reference storageReference =
          FirebaseStorage.instance.refFromURL('$storageUrl/$imagePath');
      String downloadURL = await storageReference.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print('Error: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      surfaceTintColor: white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: FutureBuilder<String>(
        future: getDownloadUrl(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      snapshot.data!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.amber[50],
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20.0, vertical: 2.0),
                            child: Text(
                              formatPrice(price),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              );
            } else {
              return const Center(
                child: Text('Failed to load image'),
              );
            }
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }
}
