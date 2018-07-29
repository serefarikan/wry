/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

grammar SAM_like;

tokens { INDENT, DEDENT }

@lexer::members {

	private boolean pendingDent = true;   // Setting this to true means we start out in `pendingDent` state and any whitespace at the beginning of the file will trigger an INDENT, which will probably be a syntax error, as it is in Python.

	private int indentCount = 0;

	private java.util.LinkedList<Token> tokenQueue = new java.util.LinkedList<>();

	private java.util.Stack<Integer> indentStack = new java.util.Stack<>();

	private Token initialIndentToken = null;

	private int getSavedIndent() { return indentStack.isEmpty() ? 0 : indentStack.peek(); }

	private CommonToken createToken(int type, String text, Token next) {
		CommonToken token = new CommonToken(type, text);
		if (null != initialIndentToken) {
			token.setStartIndex(initialIndentToken.getStartIndex());
			token.setLine(initialIndentToken.getLine());
			token.setCharPositionInLine(initialIndentToken.getCharPositionInLine());
			token.setStopIndex(next.getStartIndex()-1);
		}
		return token;
	}

	@Override
	public Token nextToken() {

		// Return tokens from the queue if it is not empty.
		if (!tokenQueue.isEmpty()) { return tokenQueue.poll(); }

		// Grab the next token and if nothing special is needed, simply return it.
		Token next = super.nextToken();
		//NOTE: This would be the appropriate spot to count whitespace or deal with NEWLINES, but it is already handled with custom actions down in the lexer rules.
		if (pendingDent && null == initialIndentToken && NEWLINE != next.getType()) { initialIndentToken = next; }
		if (null == next || HIDDEN == next.getChannel() || NEWLINE == next.getType()) { return next; }

		// Handle EOF; in particular, handle an abrupt EOF that comes without an immediately preceding NEWLINE.
		if (next.getType() == EOF) {
			indentCount = 0;
			// EOF outside of `pendingDent` state means we did not have a final NEWLINE before the end of file.
			if (!pendingDent) {
				initialIndentToken = next;
				tokenQueue.offer(createToken(NEWLINE, "NEWLINE", next));
			}
		}

		// Before exiting `pendingDent` state we need to queue up proper INDENTS and DEDENTS.
		while (indentCount != getSavedIndent()) {
			if (indentCount > getSavedIndent()) {
				indentStack.push(indentCount);
				tokenQueue.offer(createToken(DentParser.INDENT, "INDENT" + indentCount, next));
			} else {
				indentStack.pop();
				tokenQueue.offer(createToken(DentParser.DEDENT, "DEDENT"+getSavedIndent(), next));
			}
		}
		pendingDent = false;
		tokenQueue.offer(next);
		return tokenQueue.poll();
	}

}

script : ( NEWLINE | structure )* EOF ;

structure
	:	field
	|	namedBlock
	|	paragraph
	;

field : NAME attributeDeclare? COLON text NEWLINE ;
	   
namedBlock : NAME attributeDeclare? NEWLINE INDENT structure+ DEDENT ;

paragraph : line* NEWLINE ;

line : text NEWLINE ;
			
text : . ;

attributeDeclare : LANG text RANG ;

NAME : [a-zA-Z_]+ [a-zA-Z_0-9]* ;

NEWLINE : ( '\r'? '\n' | '\r' ) { if (pendingDent) { setChannel(HIDDEN); } pendingDent = true; indentCount = 0; initialIndentToken = null; } ;

WS : [ \t]+ { setChannel(HIDDEN); if (pendingDent) { indentCount += getText().length(); } } ;

BlockComment : '/*' ( BlockComment | . )*? '*/' -> channel(HIDDEN) ;   // allow nesting comments
LineComment : '//' ~[\r\n]* -> channel(HIDDEN) ;

COLON : ':' ;

LANG : '<' ;
RANG : '>' ;

LEGIT : ~[ \t\r\n]+ ~[\r\n]*;   // Replace with your language-specific rules...

