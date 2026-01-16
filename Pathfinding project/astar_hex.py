import json
from queue import PriorityQueue

# =========================
#      KONSTANTE
# =========================

CELL_SIZE = 0.5  # ena celica = 0.5 enote

# Svetovne koordinate za start in end (x, y)
START_POS = (0.0, 0.0)  # (x, y)
END_POS = (-4.0, 4.5)    # (x, y)


# =========================
#   HEX RAZDALJA (PRAVA)
# =========================

def offset_to_cube(row, col):
    """
    even-q vertical layout
    """
    x = col
    z = row - (col - (col & 1)) // 2
    y = -x - z
    return x, y, z


def hex_distance(a, b):
    ax, ay, az = offset_to_cube(*a)
    bx, by, bz = offset_to_cube(*b)
    return max(
        abs(ax - bx),
        abs(ay - by),
        abs(az - bz)
    ) * CELL_SIZE


# =========================
#           SPOT
# =========================

class Spot:
    def __init__(self, row, col, total_rows):
        self.row = row
        self.col = col
        self.total_rows = total_rows
        self.neighbors = []
        self.is_barrier = False

    def get_pos(self):
        return self.row, self.col

    def update_neighbors(self, grid):
        """
        HEX neighbors – even-q offset layout
        """
        self.neighbors = []

        if self.col % 2 == 0:
            directions = [
                (-1, 0), (1, 0),
                (0, -1), (0, 1),
                (-1, -1), (1, -1)
            ]
        else:
            directions = [
                (-1, 0), (1, 0),
                (0, -1), (0, 1),
                (-1, 1), (1, 1)
            ]

        for dr, dc in directions:
            r = self.row + dr
            c = self.col + dc
            if 0 <= r < self.total_rows and 0 <= c < self.total_rows:
                if not grid[r][c].is_barrier:
                    self.neighbors.append(grid[r][c])

    def __lt__(self, other):
        return False


# =========================
#   PRETVORBA KOORDINAT
# =========================
# KLJUČNO: x <- row, y <- col

def grid_to_world(row, col, origin):
    origin_row, origin_col = origin
    x = (row - origin_row) * CELL_SIZE
    y = (col - origin_col) * CELL_SIZE
    return round(x, 2), round(y, 2)


def world_to_grid(x, y, origin):
    """
    Pretvori svetovne koordinate (x, y) v grid indekse (row, col).
    """
    origin_row, origin_col = origin
    row = round(x / CELL_SIZE + origin_row)
    col = round(y / CELL_SIZE + origin_col)
    return row, col


# =========================
#   REKONSTRUKCIJA POTI
# =========================

def reconstruct_path(came_from, current, origin):
    path_grid = [current.get_pos()]
    while current in came_from:
        current = came_from[current]
        path_grid.append(current.get_pos())

    path_grid.reverse()
    path_world = [
        grid_to_world(r, c, origin)
        for r, c in path_grid
    ]

    return path_grid, path_world


# =========================
#            A*
# =========================

def a_star(grid, start, end, origin):
    open_set = PriorityQueue()
    open_set.put((0, start))

    came_from = {}

    g_score = {
        spot: float("inf")
        for row in grid
        for spot in row
    }
    g_score[start] = 0.0

    f_score = {
        spot: float("inf")
        for row in grid
        for spot in row
    }
    f_score[start] = hex_distance(
        start.get_pos(),
        end.get_pos()
    )

    open_set_hash = {start}

    while not open_set.empty():
        current = open_set.get()[1]
        open_set_hash.remove(current)

        if current == end:
            return reconstruct_path(came_from, end, origin)

        for neighbor in current.neighbors:
            temp_g = g_score[current] + CELL_SIZE

            if temp_g < g_score[neighbor]:
                came_from[neighbor] = current
                g_score[neighbor] = temp_g
                f_score[neighbor] = temp_g + hex_distance(
                    neighbor.get_pos(),
                    end.get_pos()
                )

                if neighbor not in open_set_hash:
                    open_set.put((f_score[neighbor], neighbor))
                    open_set_hash.add(neighbor)

    return None


# =========================
#   NALAGANJE GUI HEX MAPE
# =========================

def load_gui_hex_map(filename):
    """
    Naloži mapo, shranjeno iz pygame HEX GUI verzije.
    Zahteva ključ 'rows' v JSON.
    """
    with open(filename, "r") as f:
        data = json.load(f)

    if "rows" not in data:
        raise ValueError(
            "Mapa nima ključa 'rows'. "
            "Shrani jo z novejšo GUI HEX verzijo."
        )

    rows = data["rows"]
    grid = [
        [Spot(r, c, rows) for c in range(rows)]
        for r in range(rows)
    ]

    # zidovi
    for r, c in data.get("walls", []):
        grid[r][c].is_barrier = True

    # start / end
    start = end = None

    if data.get("start"):
        r, c = data["start"]
        start = grid[r][c]

    if data.get("end"):
        r, c = data["end"]
        end = grid[r][c]

    origin = tuple(data.get("origin", (0, 0)))

    # posodobi sosede
    for row in grid:
        for spot in row:
            spot.update_neighbors(grid)

    return grid, start, end, origin


# =========================
#     ASCII VIZUALIZACIJA
# =========================

def draw_grid_ascii(grid, path=None, start=None, end=None, origin=None):
    path = set(path or [])
    print("\nASCII prikaz HEX grida:\n")

    for r in range(len(grid)):
        line = " " if r % 2 else ""
        for c in range(len(grid)):
            if origin and (r, c) == origin:
                line += " O "
            elif start and (r, c) == start.get_pos():
                line += " S "
            elif end and (r, c) == end.get_pos():
                line += " E "
            elif grid[r][c].is_barrier:
                line += " # "
            elif (r, c) in path:
                line += " * "
            else:
                line += " . "
        print(line)


# =========================
#            MAIN
# =========================

def main():
    grid, _, _, origin = load_gui_hex_map("map.json")
    
    # Pretvori svetovne koordinate v grid indekse
    start_row, start_col = world_to_grid(START_POS[0], START_POS[1], origin)
    end_row, end_col = world_to_grid(END_POS[0], END_POS[1], origin)
    
    start = grid[start_row][start_col]
    end = grid[end_row][end_col]

    result = a_star(grid, start, end, origin)

    if result:
        path_grid, path_world = result

        print("\nNajdena pot (grid → world):\n")
        for i, ((r, c), (x, y)) in enumerate(
            zip(path_grid, path_world)
        ):
            print(
                f"{i:02d}: "
                f"grid=({r},{c}) → world=({x},{y})"
            )

        draw_grid_ascii(grid, path_grid, start, end, origin)
        
        # Shrani pot v JSON datoteko
        with open("path_output.json", "w") as f:
            json.dump(path_world, f, indent=2)
        
        print("\nPot shranjena v path_output.json")
    else:
        print("Pot ne obstaja!")


if __name__ == "__main__":
    main()
