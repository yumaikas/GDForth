# GDForth Guide

## Up and running

You'll want to copy this folder `addons/GDForth` into your Godot project. That'll give you access to the GDForth class, which you can use like so:


```gdscript

# game.gd

var forth

func _ready():
	forth = GDForth.new(self)
	forth.eval("load: game.fth")

```

```forth
( game.fth )

"This is from a GDForth Script!" print(*)

```

## GDForth in Y minutes

### GDForth in 1 minute

GDForth is a stack-based programming language. In short, that means that basic code looks like this:

```forth
1 2 + ( stack: 3 ) 
randomize()
: roll_d6 ( -- result ) randi() 6 mod 1+ ;
: win "You prevailed" print ;
: lose "They bested you!" print ;
:: opposed-roll ( -- ) roll_d6 roll_d6 ( my_roll their_roll ) ge? [ win ] [ lose ] if-else ;
```

If you're familiar with Forth or a concatenative language, that'll help you understand GDForth.

### GDForth in more minutes

```forth 
( -- Comments -- )

( GDForth currently only has `( parens for comments )`. I'll be using comments after expressions
to indicate the contents of the stack. )

( ---- Basic values ---- )

( Numbers match with GDScript, and can be either integers or floating point: )

    1 2 +   ( stack: 3 )
    6 3 div ( stack: 3 2 )
    *       ( stack: 6 )
    2 mod   ( stack: 0 )
    4 -     ( stack: -4 )

( Strings have two major forms. The first is a "keyword" form, that looks like so )

    :My :Name ( stack: "My" "Name" ) drop drop

( Usually, this form is used for things like properties or dictionary keys. )

( The second is a more traditional quoted string )

    "My name" " is not public" str(**) ( stack: "My name is not public" )

( Finally, booleans have `true` and `false` as values, with the expected operations on them. )

    true false and ( stack: false ) drop
    true false or  ( stack: true ) drop
    false not      ( stack: true ) drop

( ---- Basic stack manipulation ---- )

( GDForth has a lot of the basic stack manipulation words )

    1 dup ( stack: 1 1 ) drop
    1 2 swap ( stack: 2 1 ) div ( stack: 1 ) 
    1 2 nip ( stack: 2 ) drop

( _s prints the stack, using GDScript's print(). This would output [1,2,3] )

    1 2 3 _s 

( There is also a clear-stack word, if needed )
    clear-stack 

( ---- Definitions and locals ---- )

( Like in Forth, you use `:` to start a definition. )

    : add ( a b -- c ) + ;
    : square ( a -- 'a ) dup * ;

( If you want to use local variables, that looks like so )
( First, use `::` instead of `:` when defining a word that uses locals )
( then, use { var names here } syntax, one word per variable. )
( Words after `--` in a local definition block are ignored, )
( they're meant for commentary )
( Finally, to put a local on the value stack, prefix it with a `*` )

    :: local-swap { a b -- b a } *b *a ;

( ---- Conditional logic, loops ---- )

( [ and ] are used to define code blocks, which are used for various control-flow words )
( as a basic example, here's an `if` )

    false [ "This should not print" print ] if

( Slightly more involved, if-else is the two-armed conditional )

    false [ "This should not print" print ] [ "This -should- print" print ] if-else

( If all you need to do is repeat something, `times` hsa you covered )

40 [ "I will not abuse loops" print ] times

( If you want to control the loop exit logic yourself, you can use a while loop )
( while loops expect to have their loop condition top-of-stack after executing )
( the loop body block )
    :: while-test 
        40 { i } 
        [ "I will not abuse loops" print  
            *i 1+ { i } ( increment )
            *i 40 gt? ( condition )
        ] while ;
    while-test

( Finally, if you want to iterate over an array, the `each` loop has you covered )

    : 3array ( a b c -- < a b c > ) 3 narray ;
    1 2 3 3array [ print ] each ;

( If you want to make your own control flow words, `do-block` is the relevant word. )
( one warning: Try to avoid mixing locals and do-block in the same word. This can lead )
( to surprising behavior if the caller is using locals. See while and each in the sdtlib )
( for examples )


( BEGIN TECHNICAL DETAILS ABOUT BLOCKS BELOW )

( Digging under the hood a little, `[` is compiled into a jump to its matching `]`, and then it )
( puts the address (aka index in the code array) of the code right after it on the stack. )
( `]`, then, is just a `return` after the compile pass which takes you back to the 
( code where you left off. )
( this -does- mean you could manipulate the addresses left on the stack, but probably best to not )
( until you're ready to ignore any warnings I'd give on the matter )

( This -also- means that `[ ]` are -not- quotations in the catlang sense, in that they aren't )
( really exposed to run-time manipulation. The fact that a `[` only does a jump and pushes on a )
( number does mean that it doesn't have a lot of overhead )

( END TECHNICAL DETAILS )

( ---- The utility/subject stack ---- )

( A lot of Forths typically roll with two stacks, the value stack and the return stack. )
( GDForth has a few more, but the most user-facing one is called the utility stack. )
( It was added because the return stack tends to have two uses, managing control flow )
( and acting as as a spill for the value stack when the shuffling goes beyond what the )
( value sack can do with the available primitives. )
( The utility stack is meant to take over that value stack spill role. This allows it to be used )
( for expressive patterns that the return stack's use for control flow would make impossible )


( The basics of the util stack are fairly straightforward: )
( u< pushes TOS onto the util stack, and u> pops it off, and u@ copies the top of the util stack )
( to the value stack )

    : udup ( -- ) u@ u< ;
    : < ( -- ) stack-size u< ;
    : > ( -- arr ) stack-size u> - narray ;

    < 1 2 3 ( stack: 1 2 3 ) > ( stack: [1,2,3])

( Another name for u@ is `it` )
    : udup ( -- ) it u< ;

( The reason that "subject" a second name for the utility stack has a lot to do with objects and )
( dictionaries. )

( First, some basics of dictionaries )
( Make a new one with `dict` )

    dict ( stack: {} ) drop

( use `put ( v obj k -- )` to put values in )

    dict dup 1 swap :a put ( stack: {a:1} )  

( and `get ( obj k -- v )` to get values out )

    dup :a get ( stack: {a:1} 1 )
    drop drop

( As you can see, dictionaries aren't bad, but they often involve juggling 3 stack entries )
( to be just so.  The util stack gives us tools to not have to shuffle directly )

    dict u< 1 it :a put u> ( stack: {a:1} ) drop

( This pattern, of pushing something on to the util stack, working with it, and then move it back )
( to the value stack is handy enough it has a factoring: )

: with ( it block -- .. it ) swap u< do-block u> ;

    dict [ 1 it :a put ] with ( stack: {a:1} ) drop

( `>key` exists as a prefix word that is compiled down to `obj.key = TOS`, so this can become: )

    dict [ 1 it >a ] with ( stack: {a:1} ) 

( `.key` exists as a prefix word that compiles down to `push(TOS.key)`. )

    dup .a ( stack: {a:1} 1 ) drop drop

( Then, going a bit further, the GDForth compiler supports a few prefix/suffix patterns that )
( assuming a meaningful `it` value. )

(>>key compiles to `it >key` )

    dict [ 1 >>a ] with ( stack: {a:1} )

( and key>> compiles down to `it .key` )

    [ a>> 1 + ] with ( stack: 2 {a:1} ) drop

( Bringing this all together you get this )

    dict [
        "Xe" >>name
        10 >>HP
        100 >>gold
    ] with ( stack: {name:"Sue",HP:10,gold:100} ) 

( Finally, for times when you don't want to keep the subject on the stack, )
( there's a with! word )

    dup [ "Cipher" >>name ] with! (stack: {name:"Cipher",HP:10,gold:100} )



( ---- More fun with blocks ---- )

( One of the other tricks that can be done with blocks )
( is using them for updating local variables, via a %key prefix )

:: local-change-example { value -- 'value } [ 5 + ] %value *value ;

( or for updating properties on an object or dict )

dict [ 0 >>x 0 >>y ] with [ 2 + ] x% ( stack: {x:2,y:0} ) drop

( ---- GDForth -> GDScript FFI ---- )

( One of the nice features of GDScript is that it has -very- easy access to )
( GDScript, even by the standards of scripting langauges )

( Firstly, you can access global GDScript functions like so )

:My :String str(**) ( stack: "MyString" )

( The (**) suffix on a word indicates that it is a function call that takes two arguments )
( The  number of stars indicates the number of arguments to feed into the function off the )
( stack )

( If there's a '.' prefix on a word with an FFI-call suffix, that indicates that the word is )
( a method call, rather than an loose function )

    dict [ 
        1 >>a 2 >>b 
        :c it .has(*) 
    ] with! 
    ( stack: false )

( If you want to discard the return value for a function, add ! to the end )

    : get-file.txt ( -- text )
         File.new() [ 
             ( there's an error code here worth checking outside of )
             ( this specific example )
             "res://file.txt"  it .open(*)! 
             it .get_as_text()
             it .close(*)!
         ] with! ;


( Finally, a lot of functions like this depend on class-level constants )
( You can use @ as a prefix to get at these )

    : get-file.txt ( -- text )
         File.new() [ 
             "res://file.txt" @File.READ it .open(**) @OK eq? [ 
                 "Unable to open file.txt" @push_error(*)! suspend 
             ] if
             it .get_as_text()
             it .close(*)!
         ] with! ;

( Speaking of constants, you can make your own in GDForth via the `const:` word )

    @Color.red @Color.greeen + @Color.blue + const: WHITE
    WHITE ( stack: Color(1,1,1) )

( ---- Signals and suspend points ---- )

( One of the other things that GDForth can do is wait on signals )
( In fact, this was the motivating reason to create GDForth )
( It's yet another prefix word, ~signal_name )

: wait-for-click ( button -- evt ) ~pressed ;

( When the VM is suspended, it can be resumed by the object it has suspended on emitting the )
( expected signal )

get-button ~pressed "Button was pressed" print

( This suspension should work -anywhere- in a GDForth script )


( ---- Miscellaneous Patterns ---- )

( I've taken to useing `/` as a prefix for words that expect an `it` value )
( Usually they also tend to be short, and kinda like little fragments )

: /has? ( key -- t/f ) it .has(*) ;
: all-keys? [ true it .keys() [ /has? and ] each ] with  ;

( Another pattern, for times when I have a small piece of code that -isn't` using `it` )
( but that I want to mark as only for local use is '#' )

: #get-or-null ( key obj -- val/null ) 2dup .has(*) [ swap get ] [ 2drop null ] if-else ;  
: get-money ( obj ) :coins #get-or-null not [ 0 ] if ;

( Feel free to check out https://github.com/yumaikas/WeFarmBeneath for more examples )
    
```


