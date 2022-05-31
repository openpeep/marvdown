# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "Marvdown - Marv is a stupid simple Markdown parser that can write to HTML or JSON"
license       = "MIT"
srcDir        = "src"
bin           = @["marvdown"]
binDir        = "bin"

# Dependencies

requires "nim >= 1.6.0"
requires "tim"
requires "toktok"
requires "klymene"

task cli, "Compile for command line":
    exec "nimble build c src/cli.nim --gc:arc "
    exec "nim -d:release --gc:arc --threads:on -d:useMalloc --opt:size --spellSuggest --out:bin/marv --opt:size c src/cli"

task dev, "Compile Marvdown":
    echo "\n✨ Compiling..." & "\n"
    exec "nimble build --gc:arc -d:useMalloc"

task prod, "Compile Marvdown":
    echo "\n✨ Compiling..." & $version & "\n"
    exec "nimble build --gc:arc --threads:on -d:release -d:useMalloc --opt:size --spellSuggest"