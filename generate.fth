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

: if- ( cond block -- ) swap [ do-block true ] [ drop false ] if-else  ;
: -elif- ( conda condb block -- taken? ) u< and [ u> do-block true ] [ u> drop false ] if-else ;
: -elif ( conda condb block -- taken? ) u< and [ u> do-block ] [ u> drop ] if-else ;
: -else ( taken? block -- ) swap [ do-block ] [ drop ] if-else ;

: get-xml-parser ( -- ) :XMLParser ^ u< u@ &open( :./gd_docs/@GDScript.xml ) throw u> ;
:: empty-node? ( xml -- empty ) u< u@ XML-ELEMENT? u> &is_empty() and ;

: TABS ( n -- ) 2 * [ SP print-raw ] times ;
: TABS: ( n -- ) 2 * [ drop SP ] times ;
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
    *methods [ =m { :var SP :M_ *m :name get SP := SP :m_iota() }ES: ] each
    2 [ print ] times 

    true =first?
    { :, SP }ES: =,SP
    *methods [ =m 
        *m :args get =args 
        *m :name get =name
        *m :return get :val eq? =method-returns
        { 
         1 TABS: *first? :if :elif ? SP :m_id SP :== SP :M_ *m :name get COLON NL
        *args reversed [ =a 2 TABS: :var SP *a SP := SP :_pop() NL ] each
         2 TABS:
         *method-returns [ :var SP :ret SP := SP ] if
         *name :( *,SP &join( *args ) :) NL 
         *method-returns [ 2 TABS: :_push(ret) NL ] if
        }ES: print
        false =first?
    ] each 
    
    ( *methods print )
;
main bye 

