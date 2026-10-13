import 'package:drift/wasm.dart';

// Web only: compiled to web/drift_worker.js by the web workflow.
void main() => WasmDatabase.workerMainForOpen();
