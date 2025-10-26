import 'package:dartros/dartros.dart';

class BaseRosServices {
  static BaseRosServices? _instance;
  static BaseRosServices get instance {
    _instance ??= BaseRosServices._init();
    return _instance!;
  }

  BaseRosServices._init() {}

  void setNodeHandle(NodeHandle nodeHandle) {
    this._nodeHandle = nodeHandle;
  }

  NodeHandle? get nodeHandle => this._nodeHandle;
  NodeHandle? _nodeHandle;
}
