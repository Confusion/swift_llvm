import LLVM_C

let module = LLVMModuleCreateWithName("Hello")

let int32 = LLVMInt32Type()

let paramTypes = [int32, int32]

// need to convert paramTypes into UnsafeMutablePointer because of API requirements
var paramTypesRef = UnsafeMutablePointer<LLVMTypeRef?>.allocate(capacity: paramTypes.count)
paramTypesRef.initialize(from: paramTypes)

let returnType = int32
let functionType = LLVMFunctionType(returnType, paramTypesRef, UInt32(paramTypes.count), 0)

let sumFunction = LLVMAddFunction(module, "sum", functionType)

let entryBlock = LLVMAppendBasicBlock(sumFunction, "entry")

let builder = LLVMCreateBuilder()
LLVMPositionBuilderAtEnd(builder, entryBlock)

let a = LLVMGetParam(sumFunction, 0)
let b = LLVMGetParam(sumFunction, 1)
let temp = LLVMBuildAdd(builder, a, b, "temp")
LLVMBuildRet(builder, temp)

LLVMLinkInMCJIT()
LLVMInitializeNativeTarget()
LLVMInitializeNativeAsmPrinter()

func runSumFunction(_ a: Int, _ b: Int) -> Int {
  let functionType = LLVMFunctionType(returnType, nil, 0, 0)
  let wrapperFunction = LLVMAddFunction(module, "", functionType)
  defer {
    LLVMDeleteFunction(wrapperFunction)
  }

  let entryBlock = LLVMAppendBasicBlock(wrapperFunction, "entry")

  let builder = LLVMCreateBuilder()
  LLVMPositionBuilderAtEnd(builder, entryBlock)

  let argumentsCount = 2
  var argumentValues = [LLVMConstInt(int32, UInt64(a), 0),
                        LLVMConstInt(int32, UInt64(b), 0)]

  let argumentsPointer = UnsafeMutablePointer<LLVMValueRef?>.allocate(capacity: MemoryLayout<LLVMValueRef>.stride * argumentsCount)
  defer {
    argumentsPointer.deallocate(capacity: MemoryLayout<LLVMValueRef>.stride * argumentsCount)
  }
  argumentsPointer.initialize(from: argumentValues)

  let callTemp = LLVMBuildCall(builder,
                               sumFunction,
                               argumentsPointer,
                               UInt32(argumentsCount), "sum_temp")
  LLVMBuildRet(builder, callTemp)

  let executionEngine = UnsafeMutablePointer<LLVMExecutionEngineRef?>.allocate(capacity: MemoryLayout<LLVMExecutionEngineRef>.stride)
  let error = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: MemoryLayout<UnsafeMutablePointer<Int8>>.stride)

  defer {
    error.deallocate(capacity: MemoryLayout<UnsafeMutablePointer<Int8>>.stride)
    executionEngine.deallocate(capacity: MemoryLayout<LLVMExecutionEngineRef>.stride)
  }

  let res = LLVMCreateExecutionEngineForModule(executionEngine, module, error)
  if res != 0 {
    let msg = String(cString: error.pointee!)
    print("\(msg)")
    exit(1)
  }

  let value = LLVMRunFunction(executionEngine.pointee, wrapperFunction, 0, nil)
  let result = LLVMGenericValueToInt(value, 0)
  return Int(result)
}

print("\(runSumFunction(5, 6))")
print("\(runSumFunction(7, 142))")
print("\(runSumFunction(557, 1024))")

LLVMDisposeModule(module)
