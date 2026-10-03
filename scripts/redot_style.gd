class_name RedotStyle
extends RefCounted
## Shared tokens from https://www.redotengine.org/app.css.
## Website balance: 75% ink, 20% graphite surfaces, 5% orange-red accents.

const INK := Color("09090b")
const INK_DEEP := Color("050506")
const HEADER := Color("070708")
const SURFACE := Color("17171b")
const SURFACE_RAISED := Color("202026")
const CHROME := Color("111114")
const BORDER := Color("2a2a30")
const BORDER_STRONG := Color("3a3a42")
const TEXT := Color.WHITE
const TEXT_SECONDARY := Color("b0b0b0")
const TEXT_DIM := Color("787881")
const BRAND := Color("ff3b0a")
const BRAND_DARK := Color("d92f0b")
const BRAND_DEEP := Color("681b0c")
const BRAND_WASH := Color("23100d")
const PEACH := Color("ffc1ad")
const AMBER := Color("ff7a00")
const MAZE_WALL := Color("080f1c")
const MAZE_OUTLINE := Color("368ee8")
const MAZE_WALL_POWER := Color("1b0b08")

const BACKDROP: Shader = preload("res://shaders/redot_backdrop.gdshader")
const HERO_TEXT: Shader = preload("res://shaders/redot_hero_text.gdshader")
