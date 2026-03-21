import 'package:flutter/material.dart';
import 'post.dart';
import 'dart:math';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {

  List<Post> posts = [];

  final titleController = TextEditingController();
  final contentController = TextEditingController();

  File? selectedMedia;
  final picker = ImagePicker();

  // PICK IMAGE
  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        selectedMedia = File(picked.path);
      });
    }
  }

  // PICK VIDEO
  Future<void> pickVideo() async {
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        selectedMedia = File(picked.path);
      });
    }
  }

  // CREATE POST
  void addPost() {
    if (titleController.text.isEmpty || contentController.text.isEmpty) return;

    setState(() {
      posts.add(Post(
        id: Random().nextDouble().toString(),
        title: titleController.text,
        content: contentController.text,
        media: selectedMedia?.path, // 🔥 NEW
      ));
    });

    titleController.clear();
    contentController.clear();
    selectedMedia = null;

    Navigator.pop(context);
  }

  // UPDATE
  void updatePost(Post post) {
    titleController.text = post.title;
    contentController.text = post.content;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Post"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController),
            TextField(controller: contentController),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                post.title = titleController.text;
                post.content = contentController.text;
              });
              Navigator.pop(context);
              titleController.clear();
              contentController.clear();
            },
            child: const Text("Update"),
          )
        ],
      ),
    );
  }

  // DELETE
  void deletePost(Post post) {
    setState(() {
      posts.remove(post);
    });
  }

  // CREATE DIALOG
  void showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create Post"),
        content: SingleChildScrollView(
          child: Column(
            children: [

              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),

              TextField(
                controller: contentController,
                decoration: const InputDecoration(labelText: "Content"),
              ),

              const SizedBox(height: 10),

              if (selectedMedia != null)
                Image.file(selectedMedia!, height: 120),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: pickImage,
                  ),
                  IconButton(
                    icon: const Icon(Icons.video_library),
                    onPressed: pickVideo,
                  ),
                ],
              )
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: addPost,
            child: const Text("Post"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: const Text("Community"),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: showAddDialog,
        child: const Icon(Icons.add),
      ),

      body: Column(
        children: [

          // 🔥 ABOUT + FOLLOW SECTION
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [

                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const AlertDialog(
                          title: Text("About Us"),
                          content: Text(
                            "RaceTech is a community for riders and event enthusiasts. Join events, connect, and grow together!",
                          ),

                        ),
                      );
                    },
                    child: const Text("About Us"),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const AlertDialog(
                          title: Text("Follow Us"),
                          content: Text(
                            "Follow us on Facebook, Instagram, and TikTok @RaceTechPH",
                          ),
                        ),
                      );
                    },
                    child: const Text("Follow Us"),
                  ),
                ),

              ],
            ),
          ),

          // 🔥 POSTS
          Expanded(
            child: ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {

                final post = posts[index];

                return Padding(
                  padding: const EdgeInsets.all(10),
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        ListTile(
                          title: Text(post.title),
                          subtitle: Text(post.content),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => updatePost(post),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => deletePost(post),
                              ),
                            ],
                          ),
                        ),

                        // 🔥 MEDIA PREVIEW
                        if (post.media != null)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(12),
                            ),
                            child: Image.file(
                              File(post.media!),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        ],
      ),
    );
  }
}