package xing.template;

import xing.template.Statement.TemplateStatement;
import xing.exception.template.ParserException;
import xing.template.Expression.AssignmentExpression;
import xing.template.Expression.BinaryExpression;
import xing.template.Expression.ForConditionExpression;
import xing.template.Expression.GroupExpression;
import xing.template.Expression.IteratorExpression;
import xing.template.Expression.LiteralExpression;
import xing.template.Expression.UnaryPostExpression;
import xing.template.Expression.UnaryPrefixExpression;
import xing.template.Expression.VariableExpression;
import xing.template.Statement.BlockStatement;
import xing.template.Statement.DocStatement;
import xing.template.Statement.ExpressionStatement;
import xing.template.Statement.ForStatement;
import xing.template.Statement.IfStatement;
import xing.template.Statement.WhileStatement;

class Parser {
	private final tokens:Array<Token>;
	private var current:Int = 0;

	public function new(tokens:Array<Token>) {
		this.tokens = tokens;
	}

	public inline function parse():Statement {
		var root:BlockStatement = new BlockStatement([]);

		while (!eof()) {
			root.push(statement());
		}

		return root;
	}

	private function statement():Statement {
		if (match(Tif)) {
			advance();
			return ifStatement();
		}
		if (match(Twhile)) {
			advance();
			return whileStatement();
		}
		if (match(Tfor)) {
			advance();
			return forStatement();
		}
		if (match(TDDollar)) {
			advance();
			return templateStatement();
		}
		if (match(TLBrac)) {
			advance();
			return block();
		}
		if (match(TDoc)) {
			var s = docStatement();
			return s;
		}
		
		return expressionStatement();
	}

	private inline function block():BlockStatement {
		var statements:Array<Statement> = new Array<Statement>();
		var statementTop = 0;

		while (!match(TRBrac) && !eof()) {
			statements[statementTop++] = statement();
		}
		consume(TRBrac, "Expected '}' after a block.");

		return new BlockStatement(statements);
	}

	private inline function expressionStatement():Statement {
		var value = expression();
		consume(TSemiColon, "Expected ';' after expression");
		return new ExpressionStatement(value);
	}

	private function ifStatement():IfStatement {
		consume(TLPran, "Expected '(' after if.");
		var condition = expression();
		consume(TRPran, "Expected ')' after if.");

		var thenBranch:Statement = statement();
		var elseBranch:Statement = null;
		if (match(Telif)) {
			advance();
			elseBranch = ifStatement();
		} else if (match(Telse)) {
			advance();
			elseBranch = statement();
		}

		return new IfStatement(condition, thenBranch, elseBranch);
	}

	private inline function whileStatement():WhileStatement {
		consume(TLPran, "Expected '(' after while.");
		var condition = expression();
		consume(TRPran, "Expected ')' after while condition.");

		var body:Statement = statement();
		return new WhileStatement(condition, body);
	}

	private inline function forStatement():ForStatement {
		consume(TLPran, "Expected '(' after for.");
		var condition = forExpression();
		consume(TRPran, "Expected ')' after for condition.");

		var body:Statement = statement();
		return new ForStatement(condition, body);
	}

	private inline function templateStatement():TemplateStatement {
		var innerExpression = expression();
		consume(TDDollar, "Expected '$$' after template.");

		return new TemplateStatement(innerExpression);
	}

	private inline function docStatement():DocStatement {
		return new DocStatement(advance());
	}

	private inline function expression():Expression {
		return assignment();
	}

	private function forExpression():Expression {
		var left = expression();

		if (match(TSemiColon)) {
			advance();
			var cond = expression();
			var right:Expression;
			try {
				consume(TSemiColon, "Expected ';' after condition for initializer");
				right = expression();
			} catch (e:ParserException) {
				right = null;
			}
			return new ForConditionExpression(left, cond, right);
		}

		if (match(Tin)) {
			if (left.kind == EVariable) {
				var token = left.name;
				advance();
				var exp = expression();
				return new IteratorExpression(token, exp);
			}
			throw new ParserException('Invalid iterator initializer, expected ${ExpressionKind.EVariable} got: ${left.kind}');
		}

		return left;
	}

	private inline function assignment():Expression {
		var expr = or();
		if (matchOneOf(AssignmentExpression.assignmentOps)) {
			var op = advance();
			var value = assignment();
			if (expr.kind != EVariable) {
				throw new ParserException("Can't assign to a non variable.");
			}
			return new AssignmentExpression(expr.name, value, op);
		}
		return expr;
	}

	private inline function binary_expression(ops:Array<TokenCode>, left:Void->Expression, right:Void->Expression):Expression {
		var leftExpr:Expression = left();
		while (matchOneOf(ops)) {
			var op = advance();
			var rightExpr = right();

			leftExpr = new BinaryExpression(leftExpr, op, rightExpr);
		}

		return leftExpr;
	}

	private inline function prefix_unary_expression():Expression {
		if (matchOneOf(UnaryPrefixExpression.ops)) {
			return new UnaryPrefixExpression(advance(), primary());
		}
		return primary();
	}

	private inline function postfix_unary_expression(exp:Expression):Expression {
		if(matchOneOf(UnaryPostExpression.ops)) {
			return new UnaryPostExpression(advance(), exp);
		}

		return exp;
	}

	private inline function modulo():Expression {
		return binary_expression(BinaryExpression.moduloOps, prefix_unary_expression, prefix_unary_expression);
	}

	private inline function factor():Expression {
		return binary_expression(BinaryExpression.factorOps, modulo, modulo);
	}

	private inline function term():Expression {
		return binary_expression(BinaryExpression.termOps, factor, factor);
	}

	private inline function shift():Expression {
		return binary_expression(BinaryExpression.shiftOps, term, term);
	}

	private inline function bitwise():Expression {
		return binary_expression(BinaryExpression.bitwiseOps, shift, shift);
	}

	private inline function comparison():Expression {
		return binary_expression(BinaryExpression.compareOps, bitwise, bitwise);
	}

	private inline function interval():Expression {
		return binary_expression(BinaryExpression.intervalOps, comparison, comparison);
	}

	private inline function and():Expression {
		return binary_expression(BinaryExpression.logicalAndOp, interval, interval);
	}

	private inline function or():Expression {
		return binary_expression(BinaryExpression.logicalOrOp, and, and);
	}

	private inline function array():Expression {
		var array:Array<Expression> = [];

		if (!match(TRBrak)) {
			do {
				if (peek().code == TComma)
					advance();

				array.push(expression());
			} while (match(TComma));
		}

		consume(TRBrak, "Unterminated array.");
		return new LiteralExpression(array, XArray);
	}

	private inline function group():Expression {
		consume(TLPran, "Expected '(' for group expression.");
		var expr = expression();
		consume(TRPran, "Expected ')' after group.");
		return new GroupExpression(expr);
	}

	private inline function primary():Expression {
		if (match(Tfalse)) {
			advance();
			return new LiteralExpression(false, XBoolean);
		}
		if (match(Ttrue)) {
			advance();
			return new LiteralExpression(true, XBoolean);
		}

		if (match(TString)) {
			return new LiteralExpression(advance().literal, XString);
		}
		if (match(TInt)) {
			return postfix_unary_expression(new LiteralExpression(Std.parseInt(advance().literal), XInt));
		}
		if (match(TFloat)) {
			return postfix_unary_expression(new LiteralExpression(Std.parseFloat(advance().literal), XFloat));
		}
		if (match(TLBrak)) {
			advance();
			return array();
		}
		if (match(TLPran)) {
			return postfix_unary_expression(group());
		}

		if (match(TID)) {
			var v = postfix_unary_expression(new VariableExpression(advance()));
			return v;
		}

		throw new ParserException("Unknown value as primary.");
	}

	private inline function consume(code:TokenCode, exception:String) {
		if (match(code)) {
			advance();
			return peek(-1);
		} else
			throw new ParserException(exception);
	}

	private inline function advance():Token {
		current++;
		return peek(-1);
	}

	private inline function match(expect:TokenCode) {
		return peek().code == expect;
	}

	private inline function matchOneOf(expect:Array<TokenCode>) {
		return expect.contains(peek().code);
	}

	private inline function peek(?next:Int = 0):Token {
		return tokens[current + next];
	}

	private inline function eof():Bool {
		return peek().code == TEOF;
	}
}
