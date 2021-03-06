-module(binson).
-export([encode/1, decode/1]).

-define(BEGIN,      16#40). %%64
-define(END,        16#41). %%65
-define(BEGIN_ARR,  16#42). %%66
-define(END_ARR,    16#43). %%67
-define(TRUE,       16#44). %%68
-define(FALSE,      16#45). %%69
-define(DOUBLE,     16#46). %%70
-define(INT8,       16#10). %%16
-define(INT16,      16#11). %%17
-define(INT32,      16#12). %%18
-define(INT64,      16#13). %%19
-define(STR_LEN8,   16#14). %%20
-define(STR_LEN16,  16#15). %%21
-define(STR_LEN32,  16#16). %%22
-define(BYTE_LEN8,  16#18). %%24
-define(BYTE_LEN16, 16#19). %%25
-define(BYTE_LEN32, 16#1a). %%26

-define(BOUND8,  (1 bsl 7)).
-define(BOUND16, (1 bsl 15)).
-define(BOUND32, (1 bsl 31)).

%%------ Primitives encoding ------
encode(true)  -> <<?TRUE>>;
encode(false) -> <<?FALSE>>;

encode(Int) when is_integer(Int) ->
    if
        Int >= -?BOUND8  andalso Int < ?BOUND8  -> <<?INT8,  Int:8/integer-little>>;
        Int >= -?BOUND16 andalso Int < ?BOUND16 -> <<?INT16, Int:16/integer-little>>;
        Int >= -?BOUND32 andalso Int < ?BOUND32 -> <<?INT32, Int:32/integer-little>>;
        true                                    -> <<?INT64, Int:64/integer-little>>
    end;

encode(Float) when is_float(Float) -> <<?DOUBLE, Float/float-little>>;

encode(String) when is_list(String) ->
    Binary = list_to_binary(String),
    Len = byte_size(Binary),
    if
        Len < ?BOUND8  -> <<?STR_LEN8,  Len:8/integer-little,  Binary/binary>>;
        Len < ?BOUND16 -> <<?STR_LEN16, Len:16/integer-little, Binary/binary>>;
        true           -> <<?STR_LEN32, Len:32/integer-little, Binary/binary>>
    end;

encode(Bytes) when is_binary(Bytes) ->
    Len = byte_size(Bytes),
    if
        Len < ?BOUND8  -> <<?BYTE_LEN8,  Len:8/integer-little,  Bytes/binary>>;
        Len < ?BOUND16 -> <<?BYTE_LEN16, Len:16/integer-little, Bytes/binary>>;
        true           -> <<?BYTE_LEN32, Len:32/integer-little, Bytes/binary>>
    end;

%%------ Composites encoding ------
encode({array, Array_list}) -> encode_array(Array_list, <<?BEGIN_ARR>>);
encode(Array) when is_tuple(Array)-> encode_array(tuple_to_list(Array), <<?BEGIN_ARR>>);

encode(Object) when is_map(Object)->
    Sorted_list = lists:keysort(1, maps:to_list(Object)),
    encode_object(Sorted_list, <<?BEGIN>>).

%%------ Composites encoding additional functions ------
encode_object([], Acc) -> <<Acc/binary, ?END>>;
encode_object([{Key, Value}|Tail], Acc) ->
    Key_data = encode(Key),
    Value_data = encode(Value),
    encode_object(Tail, <<Acc/binary, Key_data/binary, Value_data/binary>>).

encode_array([], Acc) -> <<Acc/binary, ?END_ARR>>;
encode_array([Value|Tail], Acc) ->
    Value_data = encode(Value),
    encode_array(Tail, <<Acc/binary, Value_data/binary>>).

%%------ Primitives decoding ------

decode(<<?TRUE,  Rest/binary>>) -> {true, Rest};
decode(<<?FALSE, Rest/binary>>) -> {false, Rest};

decode(<<?INT8,  Int:8/signed-integer-little,  Rest/binary>>) -> {Int, Rest};
decode(<<?INT16, Int:16/signed-integer-little, Rest/binary>>) -> {Int, Rest};
decode(<<?INT32, Int:32/signed-integer-little, Rest/binary>>) -> {Int, Rest};
decode(<<?INT64, Int:64/signed-integer-little, Rest/binary>>) -> {Int, Rest};

decode(<<?DOUBLE, Float/float-little, Rest/binary>>) -> {Float, Rest};

decode(<<?STR_LEN8,  Len:8/integer-little,  Str:Len/binary, Rest/binary>>) -> {binary_to_list(Str), Rest};
decode(<<?STR_LEN16, Len:16/integer-little, Str:Len/binary, Rest/binary>>) -> {binary_to_list(Str), Rest};
decode(<<?STR_LEN32, Len:32/integer-little, Str:Len/binary, Rest/binary>>) -> {binary_to_list(Str), Rest};

decode(<<?BYTE_LEN8,  Len:8/integer-little,  Bytes:Len/binary, Rest/binary>>) -> {Bytes, Rest};
decode(<<?BYTE_LEN16, Len:16/integer-little, Bytes:Len/binary, Rest/binary>>) -> {Bytes, Rest};
decode(<<?BYTE_LEN32, Len:32/integer-little, Bytes:Len/binary, Rest/binary>>) -> {Bytes, Rest};

%%------ Composites decoding ------
decode(<<?BEGIN_ARR, Rest/binary>>) -> decode_array(Rest, []);
decode(<<?BEGIN, Rest/binary>>) -> decode_object(Rest, #{}).

%%------ Composites decoding additional functions ------
decode_object(<<?END, Rest/binary>>, Acc) -> {Acc, Rest};
decode_object(Data, Acc) ->
    {Key, Val_Rest} = decode(Data),
    {Value, Rest}   = decode(Val_Rest),
    decode_object(Rest, maps:put(Key, Value, Acc)).

decode_array(<<?END_ARR, Rest/binary>>, Acc) -> {list_to_tuple(lists:reverse(Acc)), Rest};
decode_array(Data, Acc) ->
    {Value, Rest}   = decode(Data),
    decode_array(Rest, [Value|Acc]).
