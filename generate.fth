: ^ ( name -- instance ) class-db &instance( nom ) ;
: bye ( -- ) self &quit() suspend ;
: ? ( cond a b -- chosen ) rot [ drop ] [ nip ] if-else ;

: times ( num block -- ) swap range swap each ; ( Doofy impl, replace with something  )

: null? ( val -- t/f ) null eq? ;
: eof? ( code -- bool ) 18 eq? ;
: OK 0 ;
: ok? OK eq? ;
: reversed ( arr -- arr ) &duplicate() dup &invert() ;
: NODE_ELEMENT 1 ;
: XML-ELEMENT? ( xml -- t/f ) &get_node_type() NODE_ELEMENT eq? ;
: NODE_ELEMENT_END 2 ;
: XML-ELEMENT-END? ( xml -- t/f ) &get_node_type() NODE_ELEMENT_END eq? ;

: xml-named? ( xml name -- t/f ) swap u< u@ XML-ELEMENT? u@ XML-ELEMENT-END? or [ u> &get_node_name() eq? ] [ drop false ] if-else ;
: ES? ES eq? ;

: null-if ( val cond ) [ drop null ] if ;
: ES?null ( val -- val/null ) dup ES? null-if ;


: @attr ( xml name -- val ) swap &get_named_attribute_value_safe( nom ) ES?null ; 
: /@name ( xml -- name ) :name @attr ;
: method? ( xml -- t/f ) :method xml-named? ;
: method-end? ( xml -- t/f ) u< u@ :method xml-named? u> XML-ELEMENT-END? and ;
: argument? ( xml -- t/f )  :argument xml-named? ;
: return? ( xml -- t/f )  :return xml-named? ;
: void-return? ( xml -- t/f ) :type @attr :void eq? ;
: default? ( xml -- t/f ) :default @attr null? not ;

: get-xml-parser ( -- ) :XMLParser ^ u< u@ &open( :./gd_docs/@GDScript.xml ) throw u> ;
:: empty-node? ( xml -- empty ) u< u@ XML-ELEMENT? u> &is_empty() and ;

: TABS ( n -- ) 2 * [ " " print-raw ] times ;
: TABS: ( n -- ) 2 * [ drop " " ] times ;
: [1+] [ 1+ ] ; : [1-] [ 1- ] ;

:: main ( -- ) get-xml-parser =xml 0 =depth
    { } =methods
    { } =arg-slidy-methods
    dict =method
    { } =args

    [ *xml &read() ok? =cont
        *cont [ 
            *xml XML-ELEMENT? [ 
                *xml method? [ *xml :name @attr *method :name put ] if
                *xml argument? *xml default? not and [ *args &append( *xml :name @attr ) ] if
                *xml return? [ *xml void-return? :void :val ? *method :return put ] if
            ] if
            *xml method-end? [ 
                *args *method :args put
                *methods &append( *method )
                dict =method
                { } =args
            ] if
        ] if 
    *cont ] while
    *methods [ =m { "var M_" *m :name get " = m_iota()" }ES: ] each 
    2 [ print ] times 

    true =first?
    *methods [ =m 
        *m :args get =args 
        *m :name get =name
        *m :return get :val eq? =method-returns
        { 
         1 TABS: *first? "if" "elif" ? " m_id == m_" *m :name get ":\n"
         *args reversed [ =a 2 TABS: "var " *a " = _pop()\n" ] each
         2 TABS:
             *method-returns [ "var ret = " ] if
             *name "(" ", " &join( *args ) ")\n" 
         *method-returns [ 2 TABS: "_push(ret)\n " ] if
        }ES: print
        false =first?
    ] each 
    
    ( *methods print )
   ;
main bye 

