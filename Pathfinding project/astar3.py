import json
from queue import PriorityQueue

# =========================
#      KONSTANTE
# =========================

CELL_SIZE = 0.5  # ena celica = 0.5 enote


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
        self.neighbors = []

        if self.row < self.total_rows - 1 and not grid[self.row + 1][self.col].is_barrier:
            self.neighbors.append(grid[self.row + 1][self.col])  # DOWN
        if self.row > 0 and not grid[self.row - 1][self.col].is_barrier:
            self.neighbors.append(grid[self.row - 1][self.col])  # UP
        if self.col < self.total_rows - 1 and not grid[self.row][self.col + 1].is_barrier:
            self.neighbors.append(grid[self.row][self.col + 1])  # RIGHT
        if self.col > 0 and not grid[self.row][self.col - 1].is_barrier:
            self.neighbors.append(grid[self.row][self.col - 1])  # LEFT

    def __lt__(self, other):
        return False


# =========================
#        HEURISTIKA
# =========================

def h(p1, p2):
    return (abs(p1[0] - p2[0]) + abs(p1[1] - p2[1])) * CELL_SIZE


# =========================
#   PRETVORBA KOORDINAT
# =========================
# KLJUČNO: x <- row, y <- col

def grid_to_world(row, col, origin):
    origin_row, origin_col = origin

    x = (row - origin_row) * CELL_SIZE
    y = (col - origin_col) * CELL_SIZE

    return round(x, 2), round(y, 2)


# =========================
#   REKONSTRUKCIJA POTI
# =========================

def reconstruct_path(came_from, current, origin):
    path_grid = [current.get_pos()]
    while current in came_from:
        current = came_from[current]
        path_grid.append(current.get_pos())

    path_grid.reverse()
    path_world = [grid_to_world(r, c, origin) for r, c in path_grid]

    return path_grid, path_world


# =========================
#            A*
# =========================

def a_star(grid, start, end, origin):
    open_set = PriorityQueue()
    open_set.put((0, start))

    came_from = {}

    g_score = {spot: float("inf") for row in grid for spot in row}
    g_score[start] = 0.0

    f_score = {spot: float("inf") for row in grid for spot in row}
    f_score[start] = h(start.get_pos(), end.get_pos())

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
                f_score[neighbor] = temp_g + h(neighbor.get_pos(), end.get_pos())

                if neighbor not in open_set_hash:
                    open_set.put((f_score[neighbor], neighbor))
                    open_set_hash.add(neighbor)

    return None


# =========================
#   NALAGANJE STARE MAPE
# =========================
# JSON uporablja (x, y)

def load_legacy_map(filename):
    with open(filename, "r") as f:
        data = json.load(f)

    rows = data["rows"]
    grid = [[Spot(r, c, rows) for c in range(rows)] for r in range(rows)]

    # zidovi: (x,y) -> (row,col)
    for x, y in data.get("walls", []):
        grid[y][x].is_barrier = True

    # start/end: (x,y)
    sx, sy = data["start"]
    ex, ey = data["end"]

    start = grid[sy][sx]
    end = grid[ey][ex]

    # origin: (x,y) -> (row,col)
    if "origin" in data:
        ox, oy = data["origin"]
        origin = (oy, ox)
    else:
        origin = (0, 0)

    for row in grid:
        for spot in row:
            spot.update_neighbors(grid)

    return grid, start, end, origin


# =========================
#     ASCII VIZUALIZACIJA
# =========================

def draw_grid_ascii(grid, path=None, start=None, end=None, origin=None):
    path = set(path or [])
    print("\nVizualni prikaz grida:\n")

    for r in range(len(grid)):
        line = ""
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
    grid, start, end, origin = load_legacy_map("spot1.json")

    result = a_star(grid, start, end, origin)

    if result:
        path_grid, path_world = result

        print("\nNajdena pot (grid → world):\n")
        for i, ((r, c), (x, y)) in enumerate(zip(path_grid, path_world)):
            print(f"{i:02d}: grid=({r},{c}) → world=({x},{y})")

        draw_grid_ascii(grid, path_grid, start, end, origin)
    else:
        print("Pot ne obstaja!")


if __name__ == "__main__":
    main()
