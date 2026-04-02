import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import '../profile/post.dart';

class CreatePostSheet extends StatefulWidget {
  final Function(String, String) onPost;
  const CreatePostSheet({
    super.key,
    required this.onPost,
  });

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {

  List<Post> posts = [];

  final titleController = TextEditingController();
  final contentController = TextEditingController();

  File? selectedMedia;
  final picker = ImagePicker();

  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        selectedMedia = File(picked.path);
      });
    }
  }

  Future<void> pickVideo() async {
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        selectedMedia = File(picked.path);
      });
    }
  }

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

  void deletePost(Post post) {
    setState(() {
      posts.remove(post);
    });
  }

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Create Post",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: "Title",
                border: UnderlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                hintText: "Content",
                border: UnderlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [

                IconButton(
                  icon: const Icon(Icons.image_outlined),
                  onPressed: pickImage,
                ),

                IconButton(
                  icon: const Icon(Icons.video_library_outlined),
                  onPressed: pickVideo,
                ),
              ],
            ),

            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {

                  //prevent empty post
                  if (titleController.text.isEmpty ||
                      contentController.text.isEmpty) {
                    return;
                  }

                  //send data back to PlacesPage
                  widget.onPost(
                    titleController.text,
                    contentController.text,
                  );

                  //close modal
                  Navigator.pop(context);
                },
                child: const Text(
                  "Post",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}