import toktok
import std/[ropes]

from std/strutils import indent, `%`
from std/os import getCurrentDir

tokens:
    Dot         > '.'
    Hyphen      > '-'
    Code        > '`' .. '`'
    Note        > '^'
    Lpar        > '('
    Rpar        > ')'
    Lspar       > '['
    Rspar       > ']'
    Lcur        > '{'
    Rcur        > '}'
    Pipe        > '|'
    Strike      > "~~" .. "~~"
    Highlight   > "==" .. "=="
    # H2          > ('#', '#')
    # H3          > ('#', '#', '#')
    # H4          > ('#', '#', '#', '#')
    H1          > '#' .. EOL
    Bold        > "**" .. "**"
    Italic      > '*' .. '*'
    ItalicAlt   > '_' .. '_'
    Paragraph
    # Heading   > @["######", "#####", "####", "###", "##", "#"] .. EOL

type
    MarvEngine = enum
        HTML, JSON

    Node = ref object

    Parser* = object
        lex*: Lexer
        prev, current, next, lastKey: TokenTuple
        contents: Rope
        tag: string
        error: string

    NodeType = enum
        NTItalic
        NTBold
        NTUnderline
        NTParagraph

    PrefixFunction = proc(parser: var Parser)

    Marvdown = object
        filePath: string
        engine: MarvEngine

const NewLine = "\n"

proc setError[T: Parser](p: var T, msg: string) =
    p.error = "Error ($2:$3): $1" % [msg, $p.current.line, $p.current.col]

proc hasError*[T: Parser](p: var T): bool =
    result = p.error.len != 0

proc getError*[T: Parser](p: var T): string =
    result = p.error

proc isEOF*(token: TokenTuple): bool =
    result = token.kind == TK_EOF

template jump[P: Parser](p: var P, offset = 1): untyped =
    var i = 0
    while offset > i:
        inc i
        p.prev = p.current
        p.current = p.next
        p.next = p.lex.getToken()
        if p.next.kind == TK_IDENTIFIER:
            p.next.kind = TK_STRING
        # while p.next.kind == TK_COMMENT:
        #     p.next = p.lex.getToken()

proc init[M: typedesc[Marvdown]](marv: M, filePath: string, engine: MarvEngine = HTML): Marvdown =
    ## Initialize Marvdown
    result = marv(engine: engine, filePath: filePath)

proc isBlockType(token: TokenKind): bool =
    result = token in {TK_H1, TK_PARAGRAPH}

proc openTag(p: var Parser): string {.inline.} =
    result = "<" & p.tag & ">"

proc closeTag(p: var Parser): string {.inline.} =
    result = "</" & p.tag & ">"
    setLen(p.tag, 0)

proc writeHtmlElement(p: var Parser) =
    ## Write a HTML Element
    if p.current.kind.isBlockType():
        add p.contents, p.openTag
    else:
        add p.contents, indent(p.openTag, p.current.wsno)
    add p.contents, p.current.value
    add p.contents, p.closeTag

proc writeBlockElement(p: var Parser) =
    ## Write a HTML Element (adds a new line after element)
    if p.current.line > p.prev.line:
        add p.contents, NewLine
    # else:
    #     p.setError("Invalid heading")
    #     return
    p.writeHtmlElement()
    add p.contents, NewLine

proc getPrefixFn[P: Parser](p: var P): PrefixFunction =
    case p.current.kind:
        of TK_H1:
            p.tag = "h1"
            result = writeBlockElement
        of TK_ITALIC:
            p.tag = "em"
            result = writeHtmlElement
        of TK_IDENTIFIER:
            if p.current.col == 0:
                p.tag = "p"
                add p.contents, p.openTag
                add p.contents, p.current.value
        of TK_STRING:
            add p.contents, indent(p.current.value, p.current.wsno)
            if p.next.line > p.current.line:
                p.tag = "p"
                add p.contents, p.closeTag
        of TK_INTEGER:
            if p.next.kind == TK_DOT:
                # Handle oredered lists
                p.tag = "li"
                jump p, 2
                result = writeBlockElement
        of TK_CODE:
            p.tag = "code"
            result = writeHtmlElement
        else: discard

proc walk[P: Parser](p: var P) =
    while p.hasError == false and p.lex.hasError == false:
        if p.current.isEOF(): break
        let prefixFn = p.getPrefixFn()
        if prefixFn != nil:
            p.prefixFn()
        # echo p.current
        jump p

proc parse[M: Marvdown](marv: var M): Parser =
    ## Parse current Markdown contents to either HTML or JSON
    var p: Parser = Parser(lex: Lexer.init(marv.filePath.readFile))
    p.current  = p.lex.getToken()
    p.next  = p.lex.getToken()
    p.walk()
    result = p

when isMainModule:
    var marv = Marvdown.init(filePath = getCurrentDir() & "/sample.md", engine = HTML)
    var p = marv.parse()
    if p.hasError:
        echo p.getError
    else:
        echo p.contents