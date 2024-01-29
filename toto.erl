-module(toto).
-import(timer, [sleep/1]).
-export([create_tree/2, root/2, leaf/1, validate_numbers/1, start/1]).

-define(MAX_LEAVES, 6).
-define(DELETED_LEAF, 3).

create_tree(Size, EnteredNumbers) ->
    Root = spawn(toto, root, [#{}, EnteredNumbers]),
    io:format("Root ~p started.~n", [Root]),
    lists:foreach(
        fun(_) ->
            Leaf = spawn_link(toto, leaf, [Root]),
            Root ! {setLeaf, Leaf}
        end,
        lists:seq(1, Size)
    ),
    Root.

root(Map, EnteredNumbers) ->
    process_flag(trap_exit, true),
    receive
        work ->
            lists:foreach(
                fun(Leaf) ->
                    Leaf ! work
                end,
                maps:keys(Map)
            ),
            root(Map, EnteredNumbers);
        {return, GeneratedNumber, Leaf} ->
            Values = maps:values(Map),
            case lists:member(GeneratedNumber, Values) of
                true ->
                    % If the number exists, ask the leaf to generate a new number
                    io:format("Duplicate number from leaf ~p, requesting new number ~n", [Leaf]),
                    Leaf ! work,
                    root(Map, EnteredNumbers);
                false ->
                    % If the number does not exist, update the map with a new entry <Leaf,GeneratedNumber>
                    NewMap = maps:put(Leaf, GeneratedNumber, Map),
                    root(NewMap, EnteredNumbers)
            end;
        {setLeaf, Leaf} ->
            % Initialize the new leaf in the map with a placeholder number(0)
            NewMap = maps:put(Leaf, 0, Map),
            root(NewMap, EnteredNumbers);
        {exiting, Leaf} ->
            % Remove the Leaf's entry from the map
            NewMap = maps:remove(Leaf, Map),
            NewLeaf = spawn_link(toto, leaf, [self()]),
            io:format("Creating new leaf: ~p ~n", [NewLeaf]),
            NewLeaf ! work,
            root(NewMap, EnteredNumbers);
        {exit_test, Nth} ->
            case lists:nth(Nth, maps:keys(Map)) of
                Leaf when is_pid(Leaf) ->
                    Leaf ! exit,
                    root(Map, EnteredNumbers)
            end;
        print ->
            SortedValues = lists:sort(maps:values(Map)),
            io:format("______________________________________~n"),
            io:format("Lottery numbers: ~p~n", [SortedValues]),
            io:format("Entered numbers: ~p~n", [EnteredNumbers]),
            GuessedNumbers = length([Num || Num <- EnteredNumbers, lists:member(Num, SortedValues)]),
            io:format("Guessed numbers: ~p~n", [GuessedNumbers]),
            root(Map, EnteredNumbers);
        Any ->
            io:format("Unrecognized message: ~p~n", [Any]),
            root(Map, EnteredNumbers)
    end.

leaf(Root) ->
    receive
        work ->
            sleep(100),
            GeneratedNumber = rand:uniform(49),
            io:format("Leaf ~p generated number: ~p ~n", [self(), GeneratedNumber]),
            Root ! {return, GeneratedNumber, self()},
            leaf(Root);
        exit ->
            io:format("Killing: ~p ~n", [self()]),
            Root ! {exiting, self()},
            exit(normal);
        Any ->
            io:format("Unrecognized message: '~p' ~n", [Any]),
            leaf(Root)
    end.

validate_numbers(EnteredNumbers) ->
    if
        length(EnteredNumbers) =/= 6 ->
            {error, "Input must contain exactly 6 numbers."};
        true ->
            UniqueNumbers = lists:usort(EnteredNumbers),
            if
                length(UniqueNumbers) =/= 6 ->
                    {error, "Numbers must be unique."};
                true ->
                    case
                        lists:all(
                            fun(N) -> is_integer(N) andalso N >= 1 andalso N =< 49 end,
                            UniqueNumbers
                        )
                    of
                        true -> ok;
                        false -> {error, "All numbers must be whole numbers between 1 and 49."}
                    end
            end
    end.

start(EnteredNumbers) when is_list(EnteredNumbers) ->
    case validate_numbers(EnteredNumbers) of
        ok ->
            Root = create_tree(?MAX_LEAVES, EnteredNumbers),
            Root ! work,
            sleep(500),
            Root ! {exit_test, ?DELETED_LEAF},
            sleep(500),
            Root ! print,
            sleep(10),
            ok;
        {error, Reason} ->
            {error, Reason}
    end.
