import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tuple/tuple.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class Entity {
  final Map<Type, dynamic> _components = {};

  T? get<T>() {
    return _components[T];
  }

  void addComponent<T>(T component) {
    _components[T] = component;
  }
}

class FileComponent {
  String filePath;

  FileComponent(this.filePath);
}

class TreeNode with Entity {
  int level;
  bool isDir;
  bool isExpanded;
  String text;

  TreeNode(this.level, this.text, {this.isDir = false, this.isExpanded = false});

  TreeNode copyWith({bool? isExpanded}) {
    return TreeNode(level, text, isDir: isDir, isExpanded: isExpanded ?? this.isExpanded);
  }
}

abstract class TreeModel {
  TreeNode nodeAtIndex(int i);
  Future<bool> toggleAtIndex(int i);
}

typedef TreeNodeList = List<Tuple2<String, TreeNode>>;

class FileTreeModel with ChangeNotifier implements TreeModel {
  TreeNodeList _nodes = [];

  FileTreeModel();

  int get count => _nodes.length;

  @override
  TreeNode nodeAtIndex(int i) {
    return _nodes[i].item2;
  }

  void openDir(String path) async {
    _nodes = await readNodes(0, path);
    notifyListeners();
  }

  @override
  Future<bool> toggleAtIndex(int i) async {
    print("Toggle at index $i");
    if (i > _nodes.length) return false;

    var node = _nodes[i];
    if (node.item2.isExpanded) {
      _nodes = _nodes
          .where((element) => !element.item1.startsWith(node.item1) || element == node)
          .map((element) => element == node ? Tuple2(element.item1, element.item2.copyWith(isExpanded: false)) : element)
          .toList();

      notifyListeners();
      return true;
    } else {
      if (!node.item2.isDir) return false;

      var treeNodeList = await readNodes(node.item2.level, node.item1);
      _nodes = [
        ..._nodes.sublist(0, i), 
        Tuple2(node.item1, node.item2.copyWith(isExpanded: true)), 
        ...treeNodeList,
        ..._nodes.sublist(i + 1)];

      notifyListeners();
      return true;
    }
  }

  Future<TreeNodeList> readNodes(int parentLevel, String directory) async {
    return Directory(directory)
        .list()
        .map((entity) =>
            Tuple2(entity.path, TreeNode(parentLevel + 1, p.basename(entity.path), isDir: entity is Directory)))
        .toList();
  }
}

final treeProvider = ChangeNotifierProvider((ref) {
  var fileTreeModel = FileTreeModel();
  fileTreeModel.openDir("/Users/daniel.doubleday/Source/MyProjects/flutter/tree_test");
  return fileTreeModel;
});

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme:
          ThemeData(primarySwatch: Colors.blue, textTheme: const TextTheme(bodyText2: TextStyle(color: Colors.black))),
      home: const MyHomePage(title: 'Directory Listing'),
    );
  }
}

class MyHomePage extends ConsumerWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: ConstrainedBox(
          constraints: const BoxConstraints.expand(),
          child: Consumer(builder: (context, ref, child) {
            var treeModel = ref.watch(treeProvider);            

            return ListView.builder(
              itemCount: treeModel.count,
              itemBuilder: (context, index) {
                var node = treeModel.nodeAtIndex(index);
                var icon = node.isExpanded
                    ? Icons.folder_open_outlined
                    : node.isDir
                        ? Icons.folder_outlined
                        : Icons.file_open_outlined;

                return Row(
                  children: [
                    SizedBox(width: node.level * 24,),
                    IconButton(
                      icon: Icon(icon),
                      onPressed: () => treeModel.toggleAtIndex(index),
                    ),
                    SizedBox(
                      height: 24,
                      child: Text(treeModel.nodeAtIndex(index).text, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                );
              },
            );
          })),
    );
  }
}
