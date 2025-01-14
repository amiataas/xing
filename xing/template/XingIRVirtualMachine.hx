package xing.template;

import haxe.Exception;
import haxe.ds.ReadOnlyArray;
import xing.template.XingCode.Address;

class XingIRVirtualMachine {
	public var output(get, null):String = "";
	
	private final ir:ReadOnlyArray<XingCode>;
	private var context:Context;
	private var accum:Dynamic = 0; // Accumulator
	private var r1:Dynamic = 0; // reg1
	private var r2:Dynamic = 0; // reg2
	private var pos:Int = 0;

	public function new(ir:ReadOnlyArray<XingCode>) {
		this.ir = ir;
	}

	public function switchContext(context:Context) {
		this.context = context;
		this.accum = 0;
		this.r1 = 0;
		this.r2 = 0;
		this.pos = 0;
		this.output = this.generateTemplate();
	}

	private function get_output():String {
		return this.output;
	}

	private function generateTemplate():String {
		var t = "";

		var code:XingCode = {opcode: NOP}
		while (code.opcode != EOF) {
			code = ir[pos];
			switch (code.opcode) {
				case NOP:
					pos++;
				case EOF:
					break;
				case DOC:
					t += code.arg1.Literal;
					pos++;
				case ORA, XOR, AND, SHL, SHR, ADD, SUB, MUL, DIV, MOD, LGA, LGO, CEQ, CNQ, CLT, CGT, CLTE, CGTE:
					switch (code.arg1.kind) {
						case Literal:
							r1 = code.arg1.Literal;
						case Variable:
							r1 = context.get(code.arg1.Variable);
						case Special:
							r1 = accum;
						default:
							error();
					}
					switch (code.arg2.kind) {
						case Literal:
							r2 = code.arg2.Literal;
						case Variable:
							r2 = context.get(code.arg2.Variable);
						case Special:
							r2 = accum;
						default:
							error();
					}
					switch (code.opcode) {
						case ORA:
							accum = r1 | r2;
						case XOR:
							accum = r1 ^ r2;
						case AND:
							accum = r1 && r2;
						case SHL:
							accum = r1 << r2;
						case SHR:
							accum = r1 >> r2;
						case ADD:
							accum = r1 + r2;
						case SUB:
							accum = r1 - r2;
						case MUL:
							accum = r1 * r2;
						case DIV:
							accum = r1 / r2;
						case MOD:
							accum = r1 % r2;
						case LGA:
							accum = r1 && r2;
						case LGO:
							accum = r1 || r2;
						case CEQ:
							accum = r1 == r2;
						case CNQ:
							accum = r1 != r2;
						case CLT:
							accum = r1 < r2;
						case CGT:
							accum = r1 > r2;
						case CLTE:
							accum = r1 <= r2;
						case CGTE:
							accum = r1 >= r2;
						default:
							error();
					}
					pos++;
				case EVL:
					t += Std.string(accum);
					pos++;
				case JMP:
					handleAddress(code.arg1.Address);
				case JNQ: // Jump not equal
					switch (code.arg1.kind) {
						case Literal:
							r1 = code.arg1.Literal;
						case Variable:
							r1 = context.get(code.arg1.Variable);
						case Special:
							r1 = accum;
						default:
							error();
					}
					switch (code.arg2.kind) {
						case Literal:
							r2 = code.arg2.Literal;
						case Variable:
							r2 = context.get(code.arg2.Variable);
						case Special:
							r2 = accum;
						default:
							error();
					}
					if (code.arg3.Address == null)
						error();

					if (r1 != r2)
						handleAddress(code.arg3.Address);
					else
						pos++;
				case JEQ: // Jump equal
					switch (code.arg1.kind) {
						case Literal:
							r1 = code.arg1.Literal;
						case Variable:
							r1 = context.get(code.arg1.Variable);
						case Special:
							r1 = accum;
						default:
							error();
					}
					switch (code.arg2.kind) {
						case Literal:
							r2 = code.arg2.Literal;
						case Variable:
							r2 = context.get(code.arg2.Variable);
						case Special:
							r2 = accum;
						default:
							error();
					}
					if (code.arg3.Address == null)
						error();

					if (r1 == r2)
						handleAddress(code.arg3.Address);
					else
						pos++;
				case LDA:
					switch (code.arg1.kind) {
						case Literal:
							accum = code.arg1.Literal;
						case Variable:
							accum = context.get(code.arg1.Variable);
						default:
							error();
					}
					pos++;
				case MOV:
					switch (code.arg1.kind) {
						case Special:
							r1 = accum;
						case Literal:
							r1 = code.arg1.Literal;
						default:
							error();
					}
					switch (code.arg2.kind) {
						case Variable:
							this.context.set(code.arg2.Variable, this.r1);
						default:
							error();
					}
					pos++;
				default:
			}
		}
		return t;
	}

	private inline function error():Void {
		throw new Exception("Invalid Operation.");
	}

	private inline function handleAddress(address:Address):Void {
		switch (address) {
			case Relative(addr):
				pos += addr;
			case Absolute(addr):
				pos = addr;
		}
		if (pos < 0) {
			pos = 0;
		} else {
			if (pos >= ir.length) {
				pos = ir.length - 1;
			}
		}
	}
}
