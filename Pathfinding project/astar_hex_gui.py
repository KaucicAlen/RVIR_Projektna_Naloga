import pygame
import math
import json
import os
from queue import PriorityQueue

pygame.init()

# =========================
# OKNO
# =========================
WIDTH = 800
WIN = pygame.display.set_mode((WIDTH, WIDTH))
pygame.display.set_caption("A* HEX Path Finding – Fixed GUI")

# =========================
# FONT
# =========================
FONT = pygame.font.SysFont("Arial", 8)

# =========================
# BARVE
# =========================
WHITE = (255,255,255)
BLACK = (0,0,0)
GREY = (150,150,150)
RED = (255,0,0)
GREEN = (0,255,0)
ORANGE = (255,165,0)
TURQUOISE = (64,224,208)
PURPLE = (128,0,128)

# =========================
# KOORDINATE
# =========================
origin = (0,0)
TILE_UNIT = 0.5

# =========================
# HEX RAZDALJA (PRAVA)
# =========================
def offset_to_cube(row, col):
    x = col
    z = row - (col - (col & 1)) // 2
    y = -x - z
    return x, y, z

def hex_distance(a, b):
    ax, ay, az = offset_to_cube(*a)
    bx, by, bz = offset_to_cube(*b)
    return max(abs(ax-bx), abs(ay-by), abs(az-bz))

# =========================
# SPOT
# =========================
class Spot:
    def __init__(self, row, col, size, rows):
        self.row = row
        self.col = col
        self.size = size
        self.rows = rows
        self.x = col * size
        self.y = row * size
        self.color = WHITE
        self.neighbors = []

    def get_pos(self):
        return self.row, self.col

    def is_barrier(self):
        return self.color == BLACK

    def reset(self):
        self.color = WHITE

    def make_start(self): self.color = ORANGE
    def make_end(self): self.color = TURQUOISE
    def make_open(self): self.color = GREEN
    def make_closed(self): self.color = RED
    def make_barrier(self): self.color = BLACK
    def make_path(self): self.color = PURPLE

    def draw(self, win):
        cx = self.x + self.size // 2
        cy = self.y + self.size // 2
        r = self.size * 0.48

        points = []
        for i in range(6):
            angle = math.pi/3*i + math.pi/6
            points.append((
                cx + r * math.cos(angle),
                cy + r * math.sin(angle)
            ))

        pygame.draw.polygon(win, self.color, points)
        pygame.draw.polygon(win, GREY, points, 1)

        rx = (self.row - origin[0]) * TILE_UNIT
        ry = (self.col - origin[1]) * TILE_UNIT
        txt = FONT.render(f"{rx:.1f},{ry:.1f}", True, BLACK)
        win.blit(txt, txt.get_rect(center=(cx, cy)))

    def update_neighbors(self, grid):
        self.neighbors = []
        if self.col % 2 == 0:
            dirs = [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,-1)]
        else:
            dirs = [(-1,0),(1,0),(0,-1),(0,1),(-1,1),(1,1)]

        for dr, dc in dirs:
            r, c = self.row + dr, self.col + dc
            if 0 <= r < self.rows and 0 <= c < self.rows:
                if not grid[r][c].is_barrier():
                    self.neighbors.append(grid[r][c])

    def __lt__(self, other):
        return False

# =========================
# GRID
# =========================
def make_grid(rows, width):
    grid = []
    gap = width // rows
    for r in range(rows):
        grid.append([])
        for c in range(rows):
            grid[r].append(Spot(r, c, gap, rows))
    return grid

# =========================
# HEX KLIK
# =========================
def get_clicked_hex(pos, grid):
    mx, my = pos
    best = None
    best_d = float("inf")
    for row in grid:
        for s in row:
            cx = s.x + s.size//2
            cy = s.y + s.size//2
            d = math.hypot(mx-cx, my-cy)
            if d < best_d:
                best_d = d
                best = s
    return best

# =========================
# A*
# =========================
def reconstruct_path(came_from, current, draw):
    path = []
    while current in came_from:
        path.append(current.get_pos())
        current = came_from[current]
        current.make_path()
        draw()
    path.append(current.get_pos())
    path.reverse()

    with open("pot.txt","w") as f:
        for r,c in path:
            x = (r-origin[0])*TILE_UNIT
            y = (c-origin[1])*TILE_UNIT
            f.write(f"{x},{y}\n")

def algorithm(draw, grid, start, end):
    open_set = PriorityQueue()
    open_set.put((0,start))
    came_from = {}

    g = {s:float("inf") for row in grid for s in row}
    g[start] = 0

    f = {s:float("inf") for row in grid for s in row}
    f[start] = hex_distance(start.get_pos(), end.get_pos())

    open_hash = {start}

    while not open_set.empty():
        current = open_set.get()[1]
        open_hash.remove(current)

        if current == end:
            reconstruct_path(came_from, end, draw)
            return True

        for n in current.neighbors:
            tg = g[current] + 1
            if tg < g[n]:
                came_from[n] = current
                g[n] = tg
                f[n] = tg + hex_distance(n.get_pos(), end.get_pos())
                if n not in open_hash:
                    open_set.put((f[n], n))
                    open_hash.add(n)
                    n.make_open()

        draw()
        if current != start:
            current.make_closed()
    return False

# =========================
# SAVE / LOAD (POPOLNO POPRAVLJENO)
# =========================
def save_map(grid, start, end, rows, name="map.json"):
    data = {
        "rows": rows,
        "start": start.get_pos() if start else None,
        "end": end.get_pos() if end else None,
        "walls": [s.get_pos() for row in grid for s in row if s.is_barrier()],
        "origin": origin
    }
    with open(name,"w") as f:
        json.dump(data,f,indent=2)

def load_map(name="map.json"):
    global origin
    with open(name) as f:
        data = json.load(f)

    rows = data["rows"]
    grid = make_grid(rows, WIDTH)

    for r,c in data.get("walls", []):
        grid[r][c].make_barrier()

    start = end = None
    if data.get("start"):
        r,c = data["start"]
        start = grid[r][c]
        start.make_start()

    if data.get("end"):
        r,c = data["end"]
        end = grid[r][c]
        end.make_end()

    origin = tuple(data.get("origin", (0,0)))

    return grid, start, end, rows

# =========================
# DRAW
# =========================
def draw(win, grid):
    win.fill(WHITE)
    for row in grid:
        for s in row:
            s.draw(win)
    pygame.display.update()

# =========================
# MAIN
# =========================
def main():
    global origin
    ROWS = 15
    grid = make_grid(ROWS, WIDTH)
    start = end = None
    run = True

    while run:
        draw(WIN, grid)
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                run = False

            if pygame.mouse.get_pressed()[0]:
                s = get_clicked_hex(pygame.mouse.get_pos(), grid)
                if not start:
                    start = s; s.make_start()
                elif not end and s != start:
                    end = s; s.make_end()
                elif s != start and s != end:
                    s.make_barrier()

            if pygame.mouse.get_pressed()[2]:
                s = get_clicked_hex(pygame.mouse.get_pos(), grid)
                s.reset()
                if s == start: start = None
                if s == end: end = None

            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_SPACE and start and end:
                    for row in grid:
                        for s in row:
                            s.update_neighbors(grid)
                    algorithm(lambda: draw(WIN, grid), grid, start, end)

                if event.key == pygame.K_c:
                    grid = make_grid(ROWS, WIDTH)
                    start = end = None

                if event.key == pygame.K_r:
                    s = get_clicked_hex(pygame.mouse.get_pos(), grid)
                    origin = s.get_pos()

                if event.key == pygame.K_s:
                    save_map(grid, start, end, ROWS)

                if event.key == pygame.K_l:
                    grid, start, end, ROWS = load_map()

    pygame.quit()

main()
