defmodule SevenGuis.Cells.ExprGraph do
  @moduledoc """
  Represents the spreadsheet's **expression graph**, which stores both
  the parsed formulas and dependency relationships between cells.

  Each cell is tracked along with:
  - Its **user input** (as a raw formula string or literal)
  - Its **parsed formula AST** (`AST.ast_node_formula/0`)
  - Its **cached evaluated value** (`AST.ast_node_value/0`)

  The graph also includes a **subscriber map**, which indicates which cells
  depend on which others — allowing efficient recalculation when values change.
  """

  alias __MODULE__
  alias SevenGuis.Cells.AstNodeTypes, as: AST
  alias SevenGuis.Cells.Coord
  alias SevenGuis.Cells.Parser

  @typedoc """
  Represents a dependency map between spreadsheet cells.

  Each key is a `%SevenGuis.Cells.Coord{}` identifying a cell,
  and each value is a `MapSet` of coordinates representing
  all cells that **subscribe** to (depend on) the value of that key cell.

  This structure allows the spreadsheet engine to efficiently determine
  which cells need to be recomputed when a particular cell changes.

  ## Example

      %{
        %Coord{row: 0, col: 0} => MapSet.new([
          %Coord{row: 1, col: 0},
          %Coord{row: 1, col: 1}
        ]),
        %Coord{row: 0, col: 1} => MapSet.new([
          %Coord{row: 2, col: 0}
        ])
      }

  In this example:
    * Cell A1 (`%Coord{row: 0, col: 0}`) is referenced by cells A2 and B2.
    * Cell B1 (`%Coord{row: 0, col: 1}`) is referenced by cell A3.
  """
  @type subscriber_map() :: %{Coord.t() => MapSet.t(Coord.t())}

  @typedoc """
  The full state of the spreadsheet’s expression graph.

  ## Fields

    * `:cells` — a map of spreadsheet cells and their associated state.
      Each key is a `%SevenGuis.Cells.Coord{}` coordinate, and each value is a tuple of:
        1. The user input (`charlist()`), e.g. `'A1 + B1'`
        2. The parsed AST (`AST.ast_node_formula()`)
        3. The cached evaluated value (`AST.ast_node_value()`)

    * `:subscribers` — a map of cell dependencies,
      where each key cell maps to a `MapSet` of cells that **depend on it**.
      See `t:subscriber_map/0` for details.

  ## Example

      %ExprGraph{
        cells: %{
          %Coord{row: 0, col: 0} => {
            ~c"1",
            {:int, 1},
            1
          },
          %Coord{row: 1, col: 0} => {
            ~c"=PRODUCT(A1, 5)",
            {:expr, {:appl, {:ident, ~c"PRODUCT"}, [{:coord, %Coord{row: 0, col: 0}}, {:int, 5}]}},
            15
          }
        },
        subscribers: %{
          %Coord{row: 0, col: 0} => MapSet.new([%Coord{row: 1, col: 0}])
        }
      }

  In this example:
    * Cell A1 contains the formula `'1 + 2'` and evaluates to `3`.
    * Cell A2 depends on A1 and caches its result (`15`).
    * The subscriber map tracks that A2 subscribes to A1.
  """
  @type t :: %ExprGraph{
          cells: %{
            Coord.t() => {
              # User input
              charlist(),
              # Parsed expression
              AST.ast_node_formula(),
              # Cached expression value
              AST.ast_node_value()
            }
          },
          subscribers: subscriber_map()
        }
  defstruct [:cells, :subscribers]

  @doc """
  Creates a new, empty expression graph.

  Initializes the spreadsheet state with no cells and no subscriber relationships.
  This function is typically used when starting a new spreadsheet or resetting the
  computational graph to a clean state.

  ## Returns

    * `%ExprGraph{}` — a struct with:
      * `cells: %{}` — an empty map of cell data
      * `subscribers: %{}` — an empty map of dependency relationships

  ## Example

      iex> SevenGuis.Cells.ExprGraph.new()
      %SevenGuis.Cells.ExprGraph{
        cells: %{},
        subscribers: %{}
      }
  """
  @spec new() :: t()
  def new() do
    %ExprGraph{
      cells: Map.new(),
      subscribers: Map.new()
    }
  end

  # _____________________ Read ExprGraph _____________________

  # ----------------- Cell Expressions/Values ----------------

  @doc """
  Retrieves the user-input string for a given cell.

  Returns the raw formula or literal as entered by the user (before parsing).

  ## Examples

      iex> expr_graph = SevenGuis.Cells.ExprGraph.new()
      iex> coord = %SevenGuis.Cells.Coord{row: 0, col: 0}
      iex> SevenGuis.Cells.ExprGraph.get_user_input(expr_graph, coord)
      ''
  """
  @spec get_user_input(t(), Coord.t()) :: charlist()
  def get_user_input(expr_graph, coord) do
    {user_input, _formula, _value} = get_cell_info(expr_graph, coord)
    user_input
  end

  @doc """
  Retrieves the parsed formula AST for a given cell.

  Returns the `AST.ast_node_formula/0` value representing the parsed form
  of the user's input. If the cell is empty or uninitialized, returns `nil`.

  ## Examples

      iex> expr_graph = SevenGuis.Cells.ExprGraph.new()
      iex> coord = %SevenGuis.Cells.Coord.coord(0, 0)
      iex> SevenGuis.Cells.ExprGraph.get_formula(expr_graph, coord)
      nil
  """
  @spec get_formula(t(), Coord.t()) :: AST.ast_node_formula() | nil
  def get_formula(expr_graph, coord) do
    {_user_input, formula, _value} = get_cell_info(expr_graph, coord)
    formula
  end

  @doc """
  Retrieves the cached evaluated value for a given cell.

  Returns the most recently computed value of the formula in that cell.
  If the cell is empty or uncomputed, returns `nil`.

  ## Examples

      iex> expr_graph = SevenGuis.Cells.ExprGraph.new()
      iex> coord = %SevenGuis.Cells.Coord.coord(0, 0)
      iex> SevenGuis.Cells.ExprGraph.get_value(expr_graph, coord)
      nil
  """
  @spec get_value(t(), Coord.t()) :: AST.ast_node_value() | nil
  def get_value(expr_graph, coord) do
    {_user_input, _formula, value} = get_cell_info(expr_graph, coord)
    value
  end

  @doc """
  Retrieves the displayable value for a given cell.

  Converts the stored value into a human-readable `charlist()` suitable for
  display in the spreadsheet UI.

  * Empty cells display as an empty string (`~c""`).
  * Error tuples are rendered as `~c"ERROR: <message>"`.
  * Any other value is converted to a charlist via `to_charlist/1`.

  ## Examples

      iex> expr_graph = SevenGuis.Cells.ExprGraph.new()
      iex> coord = %SevenGuis.Cells.Coord.coord(0, 0)
      iex> SevenGuis.Cells.ExprGraph.get_display_value(expr_graph, coord)
      []
  """
  @spec get_display_value(t(), Coord.t()) :: charlist()
  def get_display_value(expr_graph, coord) do
    case get_value(expr_graph, coord) do
      nil -> ~c""
      {:error, msg} -> ~c"ERROR: #{msg}"
      other -> to_charlist(other)
    end
  end

  @doc """
  Retrieves all cell information for a given coordinate.

  Returns a tuple of `{user_input, formula, value}` for the given cell.
  If the cell does not exist in the graph, returns a default placeholder:

      {[], nil, nil}

  ## Examples

      iex> expr_graph = SevenGuis.Cells.ExprGraph.new()
      iex> coord = %SevenGuis.Cells.Coord.coord(0, 0)
      iex> SevenGuis.Cells.ExprGraph.get_cell_info(expr_graph, coord)
      {[], nil, nil}
  """
  @spec get_cell_info(t(), Coord.t()) ::
          {charlist(), AST.ast_node_formula() | nil, AST.ast_node_value() | nil}
  def get_cell_info(expr_graph, coord) do
    Map.get(expr_graph.cells, coord, {~c"", nil, nil})
  end

  # ----------------------- Subscribers ----------------------

  @doc """
  Retrieves the set of subscribers (dependent cells) for a given coordinate.

  Returns a `MapSet` of `%Coord{}` structs representing all cells that depend on
  the specified cell's value. If the cell has no subscribers, returns an empty set.

  This function is used by the dependency engine to determine which cells need
  to be re-evaluated when a given cell changes.

  ## Examples

      iex> expr_graph = SevenGuis.Cells.ExprGraph.new()
      iex> coord = %SevenGuis.Cells.Coord.coord(0, 0)
      iex> SevenGuis.Cells.ExprGraph.get_subscribers(expr_graph, coord)
      #MapSet<[]>
  """
  @spec get_subscribers(t(), Coord.t()) :: MapSet.t(Coord.t())
  def get_subscribers(expr_graph, coord) do
    Map.get(expr_graph.subscribers, coord, MapSet.new())
  end

  # ____________________ Update ExprGraph ____________________

  # ------------------- Expressions/Values -------------------

  @doc """
  Updates a cell with new user input, recalculates its value, updates
  dependencies, and propagates changes to downstream cells.

  This function performs several steps:
    1. Parses the user input into a formula AST.
    2. Evaluates the formula to produce a new value.
    3. Updates the cell in the `ExprGraph`.
    4. Updates the subscriber/dependency graph by adding or removing
       publishers based on changed dependencies.
    5. Detects cycles in the dependency graph.
    6. If no cycles are found, recursively re-evaluates all dependent cells.

  ## Parameters

    * `expr_graph` — the current `%ExprGraph{}` representing spreadsheet state
    * `coord` — the `%Coord{}` of the cell to update
    * `user_input` — a `charlist()` containing the user-entered formula or value

  ## Returns

    * `{:ok, updated_expr_graph, downstream}` — if the update succeeded:
      - `updated_expr_graph` — the graph with the updated cell and subscribers
      - `downstream` — a `MapSet` of coordinates that were re-evaluated as a result

    * `{:error, cycles}` — if the update would introduce a circular dependency:
      - `cycles` — a list of `%Coord{}` forming the cycle
  """
  @spec update_cell(t(), Coord.t(), charlist()) ::
          {:error, list(Coord.t())}
          | {:ok, t(), MapSet.t(Coord.t())}
  def update_cell(expr_graph, coord, user_input) do
    # Update cell information
    formula = Parser.parse_formula(user_input)
    value = evaluate(expr_graph, formula) |> IO.inspect(label: "value")
    cell = {user_input, formula, value}
    cells = Map.put(expr_graph.cells, coord, cell)
    updated_expr_graph = %{expr_graph | cells: cells}

    # Update publishers
    publishers_old = dependencies(get_formula(expr_graph, coord))
    publishers_new = dependencies(formula)
    publishers_to_remove = MapSet.difference(publishers_old, publishers_new)
    publishers_to_add = MapSet.difference(publishers_new, publishers_old)

    subscribers =
      unsubscribe(expr_graph.subscribers, coord, publishers_to_remove)
      |> subscribe(coord, publishers_to_add)

    updated_expr_graph = %{updated_expr_graph | subscribers: subscribers}
    # Check for dependencies
    case find_cycles(updated_expr_graph, coord) do
      [] ->
        # Re-evaluate cells that depend on this cell
        {updated_expr_graph, downstream} = evaluate_subscribers(updated_expr_graph, coord)
        {:ok, updated_expr_graph, downstream}

      cycles ->
        {:error, cycles}
    end
  end

  @doc """
  Updates the cached value of a specific cell in the expression graph.

  This function replaces the current cached value of a cell without
  modifying its user input or parsed formula. It is typically used
  after evaluating a formula or applying a user change.

  ## Parameters

    * `expr_graph` — the `%ExprGraph{}` representing the spreadsheet state
    * `coord` — the `%Coord{}` of the cell to update
    * `value` — the new `AST.ast_node_value()` to store in the cell

  ## Returns

    * An updated `%ExprGraph{}` with the new value stored for the given cell

  ## Example

      iex> alias SevenGuis.Cells.{Coord, ExprGraph}
      iex> expr_graph = ExprGraph.new()
      iex> coord = %Coord{row: 0, col: 0}
      iex> expr_graph = %{expr_graph | cells: %{coord => {~c"1", {:int, 1}, {:int, 1}}}}
      iex> ExprGraph.update_value(expr_graph, coord, {:int, 42})
      %ExprGraph{
        cells: %{
          %Coord{row: 0, col: 0} => {~c"1", {:int, 1}, {:int, 42}}
        },
        subscribers: %{}
      }
  """
  def update_value(expr_graph, coord, value) do
    cells =
      Map.update!(
        expr_graph.cells,
        coord,
        fn {user_input, formula, _value} -> {user_input, formula, value} end
      )

    %{expr_graph | cells: cells}
  end

  # ----------------------- Subscribers ----------------------

  @doc """
  Adds a subscriber to one or more publishers in the subscriber map.

  This function is used when a cell starts depending on other cells,
  updating the dependency graph so that changes to the publishers
  trigger re-evaluation of the subscriber.

  ## Parameters

    * `subscribers` — a `subscriber_map()` representing the current mapping
      of cells to the set of cells that depend on them
    * `subscriber` — a `%Coord{}` representing the cell that depends on others
    * `publishers` — an enumerable of `%Coord{}` coordinates representing
      the cells that the subscriber depends on

  ## Returns

    * An updated `subscriber_map()` with the subscriber added to the
      specified publishers

  ## Example

      iex> alias SevenGuis.Cells.Coord
      iex> subscribers = %{
      ...>   %Coord{row: 0, col: 0} => MapSet.new(),
      ...>   %Coord{row: 0, col: 1} => MapSet.new([%Coord{row: 1, col: 0}])
      ...> }
      iex> subscriber = %Coord{row: 1, col: 0}
      iex> publishers = [%Coord{row: 0, col: 0}]
      iex> SevenGuis.Cells.ExprGraph.subscribe(subscribers, subscriber, publishers)
      %{
        %Coord{row: 0, col: 0} => MapSet.new([%Coord{row: 1, col: 0}]),
        %Coord{row: 0, col: 1} => MapSet.new([%Coord{row: 1, col: 0}])
      }
  """
  @spec subscribe(
          subscriber_map(),
          Coord.t(),
          Enumerable.t(Coord.t())
        ) :: subscriber_map()
  def subscribe(subscribers, subscriber, publishers) do
    Enum.reduce(
      publishers,
      subscribers,
      fn publisher, subscribers ->
        Map.update(
          subscribers,
          publisher,
          MapSet.new([subscriber]),
          fn subscribed ->
            MapSet.put(subscribed, subscriber)
          end
        )
      end
    )
  end

  @doc """
  Removes a subscriber from one or more publishers in the subscriber map.

  This function is used when a cell no longer depends on other cells,
  allowing the dependency graph to stay accurate and preventing
  unnecessary recomputation.

  ## Parameters

    * `subscribers` — a `subscriber_map()` representing the current mapping
      of cells to the set of cells that depend on them
    * `subscriber` — a `%Coord{}` representing the cell to remove from subscribers
    * `publishers` — an enumerable of `%Coord{}` coordinates representing
      the cells that the subscriber no longer depends on

  ## Returns

    * An updated `subscriber_map()` with the subscriber removed from the
      specified publishers

  ## Example

      iex> alias SevenGuis.Cells.Coord
      iex> subscribers = %{
      ...>   %Coord{row: 0, col: 0} => MapSet.new([%Coord{row: 1, col: 0}]),
      ...>   %Coord{row: 0, col: 1} => MapSet.new([%Coord{row: 1, col: 0}])
      ...> }
      iex> subscriber = %Coord{row: 1, col: 0}
      iex> publishers = [%Coord{row: 0, col: 0}]
      iex> SevenGuis.Cells.ExprGraph.unsubscribe(subscribers, subscriber, publishers)
      %{
        %Coord{row: 0, col: 0} => MapSet.new(),
        %Coord{row: 0, col: 1} => MapSet.new([%Coord{row: 1, col: 0}])
      }
  """
  @spec unsubscribe(
          subscriber_map(),
          Coord.t(),
          Enumerable.t(Coord.t())
        ) :: subscriber_map()
  def unsubscribe(subscribers, subscriber, publishers) do
    Enum.reduce(
      publishers,
      subscribers,
      fn publisher, subscribers ->
        Map.update(
          subscribers,
          publisher,
          MapSet.new(),
          fn subscribed ->
            MapSet.delete(subscribed, subscriber)
          end
        )
      end
    )
  end

  # __________________ Evaluating Functions __________________

  # --------------------- Evaluate a Cell --------------------

  @doc """
  Evaluates a parsed AST formula node in the context of an expression graph.

  This function computes the value of a formula or literal, recursively
  resolving cell references, function applications, and ranges. It
  handles errors gracefully and propagates them up the call stack.

  ## Parameters

  * `expr_graph` — the `%ExprGraph{}` containing cell values and dependencies
  * `ast_node` — an AST node representing the formula (`AST.ast_node_formula()`)

  ## Returns

  * `AST.ast_node_value()` — the computed value of the formula, if successful
  * `{:error, charlist()}` — if an error occurs during evaluation

  ## Behavior by AST Node Type

  * `{:appl, {:ident, function_name}, args}` — evaluates a function application:
    - Preprocesses ranges into individual coordinates
    - Evaluates each argument recursively
    - If all arguments succeed, calls the function from `lookup/1`
    - If any argument is an error, returns a descriptive error message
    - Rescues any runtime exception and returns it as an error tuple
  * `{:expr, {:range, first, second}}` — ranges are **invalid at the top-level**
    and must only appear as function arguments; returns an error tuple
  * `{:expr, expr}` — recursively evaluates nested expressions
  * `{:coord, coord}` — returns the cached value of the referenced cell
  * `{_other, value}` — returns the literal value (integer, float, or text)
  * `nil` — returns `nil` for empty cells
  """
  @spec evaluate(t(), AST.ast_node_formula()) :: AST.ast_node_value() | {:error, charlist()}
  def evaluate(expr_graph, {:appl, {:ident, function_name}, args}) do
    # IO.inspect(expr_graph, label: "expr_graph")
    function = lookup(function_name)

    case function do
      {:error, msg} ->
        {:error, msg}

      defined ->
        # Add index info for better error messages
        args =
          args
          |> preprocess_args()
          |> Enum.with_index(fn arg, index -> %{index: index, arg: arg} end)
          # |> IO.inspect(label: "args 1")
          |> Enum.map(fn arg ->
            # IO.inspect(arg, label: "arg")
            value = evaluate(expr_graph, arg.arg)
            # IO.inspect(value, label: "value")
            Map.put(arg, :value, value)
          end)
          # |> IO.inspect(label: "args 2")
          # Because we use nil as a "no-information at coordinate"
          # we want to remove nils from the function arguments
          |> Enum.reject(fn arg -> arg.value == nil end)

        # |> IO.inspect(label: "args 3")

        error_args =
          Enum.filter(args, fn arg ->
            case arg.value do
              {:error, _msg} -> true
              _ok -> false
            end
          end)

        # |> IO.inspect(label: "error_args")

        case error_args do
          [] ->
            # Strip out index info for calculation
            args =
              Enum.map(args, fn arg -> arg.value end)

            # |> IO.inspect(label: "args 4")

            try do
              defined.(args)
            rescue
              e ->
                e = Exception.format(:error, e, __STACKTRACE__)
                {:error, to_charlist(e)}
            end

          error_args ->
            error_args =
              Enum.map_intersperse(
                error_args,
                ~c", ",
                fn %{index: index, value: {:error, msg}} ->
                  ~c"#{index}: #{msg}"
                end
              )
              |> List.flatten()

            error_msg =
              List.flatten(~c"#{function_name} bad args (#{error_args})")

            # |> IO.inspect(label: "error_msg")

            {:error, error_msg}
        end
    end
  end

  def evaluate(_expr_graph, {:expr, {:range, first, second}}) do
    first = to_charlist(first)
    second = to_charlist(second)

    error_msg =
      ~c"Range (#{first}:#{second}) should only appear as function arguments, not in top-level formula"

    {:error, error_msg}
  end

  def evaluate(expr_graph, {:expr, expr}), do: evaluate(expr_graph, expr)
  def evaluate(expr_graph, {:coord, coord}), do: get_value(expr_graph, coord)
  def evaluate(_expr_graph, {_other, other_value}), do: other_value
  def evaluate(_expr_graph, nil), do: nil

  @doc """
  Preprocesses a list of AST arguments for a function application.

  This function converts any range arguments into a flat list of
  individual coordinate nodes (`{:coord, Coord.t()}`), leaving other
  arguments unchanged. This is useful for functions like `SUM` or
  `PRODUCT` that operate over multiple cells.

  ## Parameters

    * `args` — a list of AST nodes (`AST.ast_node_formula()`)

  ## Returns

    * A flat list of AST nodes, with ranges expanded into individual coordinates

  ## Example

      iex> alias SevenGuis.Cells.Coord
      iex> range = {:range, %Coord{row: 0, col: 0}, %Coord{row: 1, col: 1}}
      iex> SevenGuis.Cells.ExprGraph.preprocess_args([range, {:int, 5}])
      [
        {:coord, %Coord{row: 0, col: 0}},
        {:coord, %Coord{row: 0, col: 1}},
        {:coord, %Coord{row: 1, col: 0}},
        {:coord, %Coord{row: 1, col: 1}},
        {:int, 5}
      ]
  """
  @spec preprocess_args([AST.ast_node_formula()]) :: [AST.ast_node_formula()]
  def preprocess_args(args), do: Enum.flat_map(args, &preprocess_arg/1)

  @doc """
  Preprocesses a single AST argument.

  * If the argument is a range (`{:range, first, second}`), it is expanded
    into a list of individual coordinate nodes.
  * Otherwise, the argument is returned as a singleton list.

  ## Parameters

    * `arg` — an AST node (`AST.ast_node_formula()`)

  ## Returns

    * A list of AST nodes

  ## Example

      iex> alias SevenGuis.Cells.Coord
      iex> arg = {:range, %Coord{row: 0, col: 0}, %Coord{row: 0, col: 1}}
      iex> SevenGuis.Cells.ExprGraph.preprocess_arg(arg)
      [
        {:coord, %Coord{row: 0, col: 0}},
        {:coord, %Coord{row: 0, col: 1}}
      ]

      iex> SevenGuis.Cells.ExprGraph.preprocess_arg({:int, 5})
      [{:int, 5}]
  """
  def preprocess_arg({:range, first, second}) do
    Coord.range_to_coords(first, second)
    |> Enum.map(fn coord -> {:coord, coord} end)
  end

  def preprocess_arg(other), do: [other]

  # -------------- Evaluate Cell and Subscribers -------------

  @doc """
  Re-evaluates all cells that depend on a given coordinate.

  This is the public entry point that starts evaluation from a single
  changed cell. It automatically propagates updates to all dependent
  cells in the spreadsheet, recursively.

  ## Parameters

    * `expr_graph` — the `%ExprGraph{}` representing the spreadsheet state
    * `coord` — the `%Coord{}` of the cell that has changed

  ## Returns

    * A tuple `{updated_expr_graph, changed_cells}`:
      - `updated_expr_graph` — the new `ExprGraph` with updated values
      - `changed_cells` — a `MapSet` of all coordinates that were affected

  ## Example

      iex> coord_a = %Coord{row: 0, col: 0}
      iex> expr_graph = SevenGuis.Cells.ExprGraph.new()
      iex> {expr_graph, changed} = SevenGuis.Cells.ExprGraph.evaluate_subscribers(expr_graph, coord_a)
      iex> MapSet.member?(changed, coord_a)
      true
  """
  @spec evaluate_subscribers(t(), Coord.t()) :: {t(), MapSet.t(Coord.t())}
  def evaluate_subscribers(expr_graph, coord) do
    evaluate_subscribers(expr_graph, coord, MapSet.new([coord]))
  end

  @doc """
  Internal recursive function that evaluates subscriber cells.

  Traverses the dependency graph starting from `coord`, updating each
  dependent cell’s value by evaluating its formula. Propagates changes
  to further subscribers.

  ## Parameters

    * `expr_graph` — the current `%ExprGraph{}` state
    * `changed_cells` — a `MapSet` of coordinates that have already been updated
    * `coord` — the `%Coord{}` currently being processed

  ## Returns

    * A tuple `{updated_expr_graph, changed_cells}`:
      - `updated_expr_graph` — the graph with all affected values updated
      - `changed_cells` — the cumulative set of coordinates that were updated

  ## Notes

    * Prevents revisiting cells that are already in `changed_cells`.
    * Relies on `evaluate/2` to compute the value of each cell’s formula
      and `update_value/3` to update the graph.

  ## Example

      iex> coord_a = %Coord{row: 0, col: 0}
      iex> coord_b = %Coord{row: 0, col: 1}
      iex> expr_graph = %ExprGraph{
      ...>   cells: %{
      ...>     coord_a => {~c"1", {:int, 1}, {:int, 1}},
      ...>     coord_b => {
      ...>       ~c"SUM(A1, 1)",
      ...>       {:expr, {:appl, {:ident, ~c"SUM"}, [{:coord, coord_a}, {:int, 1}]}},
      ...>       {:int, 2}
      ...>     }
      ...>   },
      ...>   subscribers: %{
      ...>     coord_a => MapSet.new([coord_b])
      ...>   }
      ...> }
      iex> {updated_graph, changed} = SevenGuis.Cells.ExprGraph.evaluate_subscribers(expr_graph, coord_a)
      iex> MapSet.member?(changed, coord_b)
      true
  """
  @spec evaluate_subscribers(t(), Coord.t(), MapSet.t(Coord.t())) :: {t(), MapSet.t(Coord.t())}
  def evaluate_subscribers(expr_graph, coord, changed_cells) do
    subs = get_subscribers(expr_graph, coord)
    changed_cells = MapSet.union(changed_cells, subs)

    # Check if we've already changed a cell that's a

    Enum.reduce(
      subs,
      {expr_graph, changed_cells},
      fn sub, {expr_graph, changed_cells} ->
        formula = get_formula(expr_graph, sub)
        value = evaluate(expr_graph, formula)
        expr_graph = update_value(expr_graph, sub, value)
        evaluate_subscribers(expr_graph, sub, changed_cells)
      end
    )
  end

  # ________________ Find Dependencies of Cell _______________

  @doc """
  Extracts all cell coordinates referenced by a given AST formula node.

  This function recursively traverses a formula AST and collects all
  `%Coord{}` references that the expression depends on. This is used
  to build the dependency graph and update subscribers when a cell changes.

  ## Parameters

    * `ast_node` — an `AST.ast_node_formula()` representing a parsed formula

  ## Returns

    * A `MapSet` of `%Coord{}` structs representing all referenced cells

  ## Supported AST Nodes

    * `{:appl, fn_name, args}` — recursively collects dependencies from all arguments
    * `{:expr, other}` — traverses nested expressions
    * `{:range, first, second}` — expands the range into all coordinates
    * `{:coord, coord}` — returns a single coordinate
    * Any other value — returns an empty set

  ## Examples

      iex> alias SevenGuis.Cells.{Coord, AST}
      iex> formula = {:expr, {:appl, {:ident, 'SUM'}, [{:coord, %Coord{row: 0, col: 0}}, {:coord, %Coord{row: 1, col: 0}}]}}
      iex> SevenGuis.Cells.ExprGraph.dependencies(formula)
      MapSet.new([
        %Coord{row: 0, col: 0},
        %Coord{row: 1, col: 0}
      ])

      iex> range_formula = {:range, %Coord{row: 0, col: 0}, %Coord{row: 1, col: 1}}
      iex> SevenGuis.Cells.ExprGraph.dependencies(range_formula)
      MapSet.new([
        %Coord{row: 0, col: 0},
        %Coord{row: 0, col: 1},
        %Coord{row: 1, col: 0},
        %Coord{row: 1, col: 1}
      ])
  """
  @spec dependencies(AST.ast_node_formula()) :: MapSet.t(Coord.t())
  def dependencies({:appl, _fn_name, args}) do
    Enum.reduce(
      args,
      MapSet.new(),
      fn arg, deps -> MapSet.union(dependencies(arg), deps) end
    )
  end

  def dependencies({:expr, other}), do: dependencies(other)

  def dependencies({:range, first, second}) do
    MapSet.new(Coord.range_to_coords(first, second))
  end

  def dependencies({:coord, coord}), do: MapSet.new([coord])
  def dependencies(_other), do: MapSet.new()

  # -------------------- Check for Cycles --------------------

  @doc """
  Detects circular dependencies starting from the given coordinate.

  This is the public entry point that initializes the recursion path
  with the starting coordinate.

  ## Parameters

    * `expr_graph` — the `%ExprGraph{}` representing the spreadsheet state
    * `coord` — the `%Coord{}` cell to start cycle detection from

  ## Returns

    * A list of `%Coord{}` forming the cycle if a circular dependency exists,
      or an empty list if no cycles are found.

  ## Example

      iex> coord_a = %Coord{row: 0, col: 0}
      iex> coord_b = %Coord{row: 0, col: 1}
      iex> expr_graph = %ExprGraph{
      ...>   cells: %{},
      ...>   subscribers: %{
      ...>     coord_a => MapSet.new([coord_b]),
      ...>     coord_b => MapSet.new([coord_a])
      ...>   }
      ...> }
      iex> SevenGuis.Cells.ExprGraph.find_cycles(expr_graph, coord_a)
      [%Coord{row: 0, col: 0}, %Coord{row: 0, col: 1}, %Coord{row: 0, col: 0}]
  """
  @spec find_cycles(t(), Coord.t()) :: [Coord.t()]
  def find_cycles(expr_graph, coord) do
    find_cycles(expr_graph, coord, [coord])
  end

  @doc """
  Recursively detects cycles in the spreadsheet dependency graph.

  This function is called internally by `find_cycles/2`. It traverses
  subscriber relationships, tracking the recursion path to identify
  circular references.

  ## Parameters

    * `expr_graph` — the `%ExprGraph{}` representing the spreadsheet state
    * `coord` — the current `%Coord{}` being visited
    * `recursion_path` — a list of coordinates representing the current traversal path

  ## Returns

    * A list of `%Coord{}` forming a cycle if one is found
    * An empty list if no cycles exist along this path

  ## Notes

    * A cycle is returned as a list starting and ending with the repeated coordinate.
    * Only the first detected cycle is returned.

  ## Example

      iex> coord_a = %Coord{row: 0, col: 0}
      iex> coord_b = %Coord{row: 0, col: 1}
      iex> expr_graph = %ExprGraph{
      ...>   cells: %{},
      ...>   subscribers: %{
      ...>     coord_a => MapSet.new([coord_b]),
      ...>     coord_b => MapSet.new([coord_a])
      ...>   }
      ...> }
      iex> SevenGuis.Cells.ExprGraph.find_cycles(expr_graph, coord_a, [coord_a])
      [%Coord{row: 0, col: 1}, %Coord{row: 0, col: 0}]
  """
  @spec find_cycles(t(), Coord.t(), [Coord.t()]) :: [Coord.t()]
  def find_cycles(expr_graph, coord, recursion_path) do
    subscribers = get_subscribers(expr_graph, coord)

    empty_set = MapSet.new()

    case subscribers do
      ^empty_set ->
        []

      _nonempty ->
        Enum.find_value(
          subscribers,
          fn sub ->
            if sub in recursion_path do
              [sub | recursion_path]
            else
              find_cycles(expr_graph, sub, [sub | recursion_path])
            end
          end
        )
    end
  end

  # ________________________ Functions _______________________

  @doc """
  Looks up a spreadsheet function implementation by its name.

  Returns a callable Elixir function corresponding to the given function name
  (expressed as a `charlist()`), or an error tuple if the name is not recognized.

  This acts as the **function registry** for the spreadsheet evaluator,
  mapping function identifiers (e.g., `"PLUS"`, `"SUM"`) to their runtime
  implementations.

  ## Supported Functions

  ### Binary arithmetic operators
  Operate on exactly two arguments (using `binary_function/1` for arity checking):

    * `"PLUS"`  — addition (`a + b`)
    * `"MINUS"` — subtraction (`a - b`)
    * `"MULT"`  — multiplication (`a * b`)
    * `"DIV"`   — division (`a / b`)

  ### Aggregate arithmetic operators
  Operate on a list of numeric values:

    * `"SUM"`     — returns the sum of all elements in the list
    * `"PRODUCT"` — returns the product of all elements in the list

  ## Error Handling

  If no matching function name is found, an error tuple is returned:

  `{:error, ~c"No function <name>}`

  ## Examples

      iex> add = SevenGuis.Cells.Functions.lookup(~c"PLUS")
      iex> add.([2, 3])
      5

      iex> sum = SevenGuis.Cells.Functions.lookup(~c"SUM")
      iex> sum.([1, 2, 3, 4])
      10

      iex> SevenGuis.Cells.Functions.lookup(~c"FOO")
      {:error, ~c"No function FOO"}
  """
  @spec lookup(charlist()) :: (list(any()) -> any()) | {:error, charlist()}
  # Binary arithmetic operators
  def lookup(~c"PLUS"), do: binary_function(fn a, b -> a + b end)
  def lookup(~c"MINUS"), do: binary_function(fn a, b -> a - b end)
  def lookup(~c"MULT"), do: binary_function(fn a, b -> a * b end)
  def lookup(~c"DIV"), do: binary_function(fn a, b -> a / b end)

  # Arithmetic operators on lists
  def lookup(~c"SUM"), do: &Enum.sum/1
  def lookup(~c"PRODUCT"), do: &Enum.product/1

  def lookup(undefined), do: {:error, ~c"No function #{undefined}"}

  @doc """
  Wraps a two-argument (binary) function with argument count validation.

  Returns a new function that expects a list of exactly two arguments.
  If the list has two elements, it applies the provided function `f` to them.
  Otherwise, it returns an error tuple.

  This is useful when defining spreadsheet functions that operate on exactly two arguments
  (e.g., addition, subtraction, multiplication, comparisons, etc.).

  ## Parameters

    * `f` — a function of arity 2 (i.e., accepts exactly two arguments)

  ## Returns

    * a new function of arity 1 that expects a list of two elements

  ## Examples

      iex> add = SevenGuis.Cells.Functions.binary_function(fn a, b -> a + b end)
      iex> add.([2, 3])
      5

      iex> add.([1])
      {:error, "Expected 2 arguments, got 1."}

      iex> add.([1, 2, 3])
      {:error, "Expected 2 arguments, got 3."}
  """
  def binary_function(f) do
    fn args ->
      case args do
        [a, b] ->
          f.(a, b)

        other ->
          arglen = length(other)
          {:error, "Expected 2 arguments, got #{arglen}."}
      end
    end
  end
end
