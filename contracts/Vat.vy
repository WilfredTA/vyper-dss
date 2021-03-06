# @version 0.2.14





event Rely:
    usr: indexed(address)

event Deny:
    usr: indexed(address)

event File:
    what: indexed(bytes32)
    data: uint256

event FileIlk:
    ilk: indexed(bytes32)
    what: indexed(bytes32)
    data: uint256

event Hope:
    usr: indexed(address)

event Nope:
    usr: indexed(address)

event Frob:
    ilk: indexed(bytes32)
    urn: indexed(address)
    src: address
    dst: address
    dink: int256
    dart: int256

event InitIlk:
    usr: indexed(address)
    ilk: indexed(bytes32)

event Cage:
    usr: indexed(address)

event Slip:
    ilk: indexed(bytes32)
    usr: indexed(address)
    who: address
    wad: int256

event Flux:
    ilk: indexed(bytes32)
    src: indexed(address)
    dst: indexed(address)
    wad: int256
    who: address

event Move:
    src: indexed(address)
    dst: indexed(address)
    rad: uint256
    who: address

event Fork:
    ilk: indexed(bytes32)
    src: indexed(address)
    dst: indexed(address)
    dink: int256
    dart: int256

event Grab:
    ilk: indexed(bytes32)
    u: address
    v: address
    w: address
    dink: int256
    dart: int256
    who: address

event Heal:
    usr: indexed(address)
    rad: uint256

event Suck:
    u: indexed(address)
    v: indexed(address)
    rad: uint256

event Fold:
    ilk: indexed(bytes32)
    u: indexed(address)
    rate: uint256
# -- Auth --
wards: public(HashMap[address, uint256])
can: public(HashMap[address, HashMap[address, uint256]])

@internal
def _auth(usr: address):
    assert self.wards[usr] == 1, "Vat/not-authorized"

@external
def hope(usr: address):
    self.can[msg.sender][usr] = 1

@external
def nope(usr: address):
    self.can[msg.sender][usr] = 0

@internal
@view
def wish(bit: address, usr: address) -> bool:
    return ((bit == usr) or self.can[bit][usr] == 1)

@external
def rely(usr: address):
    self._auth(msg.sender)
    assert self.live == 1, "Vat/not-live"
    self.wards[usr] = 1

@external
def deny(usr: address):
    self._auth(msg.sender)
    assert self.live == 1, "Vat/not-live"
    self.wards[usr] = 0


# -- Data --

struct Ilk:
    Art: uint256 # total normalized debt
    rate: uint256 # accumulated rates
    spot: uint256 # price w/ safety margin
    line: uint256 # Debt ceiling
    dust: uint256 # Urn debt floor

struct Urn:
    ink: uint256 # locked collateral
    art: uint256 # normalized debt

ilks: public(HashMap[bytes32, Ilk])
urns: public(HashMap[bytes32, HashMap[address, Urn]])
gem: public(HashMap[bytes32, HashMap[address, uint256]]) # wad
dai: public(HashMap[address, uint256]) # rad
sin: public(HashMap[address, uint256]) # rad


debt: public(uint256) # Total dai issued (rad)
vice: public(uint256) # total unbacked Dai (rad)
Line: public(uint256) # total debt ceiling
live: public(uint256) # Active flag

@external
def __init__():
    self.wards[msg.sender] = 1
    self.live = 1



# --- Administration ---
@external
def init_ilk(ilk: bytes32):
    self._auth(msg.sender)
    assert self.ilks[ilk].rate == 0, "Vat/ilk-already-init"
    self.ilks[ilk].rate = 10 ** 27

@external
def file(what: bytes32, data: uint256):
    self._auth(msg.sender)
    assert self.live == 1, "Vat/not-live"
    if what == convert(b"Line", bytes32):
        self.Line = data
    else:
        raise "Vat/file-unrecognized-param"

@external
def file_ilk(ilk: bytes32, what: bytes32, data: uint256):
    self._auth(msg.sender)
    assert self.live == 1, "Vat/not-live"
    if what == convert(b"spot", bytes32):
        self.ilks[ilk].spot = data
    elif what == convert(b"line", bytes32):
        self.ilks[ilk].line = data
    elif what == convert(b"dust", bytes32):
        self.ilks[ilk].dust = data
    else:
        raise "Vat/file-unrecognized-param"


@external
def cage():
    self._auth(msg.sender)
    self.live = 0

# --- Fungibility ---
@external
def slip(ilk: bytes32, usr: address, wad: int256):
    self._auth(msg.sender)

    if wad < 0:
        self.gem[ilk][usr] -= convert(abs(wad), uint256)
    else:
        self.gem[ilk][usr] += convert(wad, uint256)

@external
def flux(ilk: bytes32, src: address, dst: address, wad: uint256):
    assert self.wish(src, msg.sender), "Vat/not-allowed"
    self.gem[ilk][src] -= wad
    self.gem[ilk][dst] += wad

@external
def move(src: address, dst: address, rad: uint256):
    assert self.wish(src, msg.sender), "Vat/not-allowed"
    self.dai[src] -= rad
    self.dai[dst] += rad


# --- CDP Manipulation ---

# u is address of user whose vault (urn) is being changed
# v is address of user whose gem is being used for the urn change
# w is address of user who will receive dai
@external
def frob(i: bytes32, u: address, v: address, w: address, dink: int256, dart: int256):
    assert self.live == 1, "Vat/not-live"
    urn: Urn = self.urns[i][u]
    ilk: Ilk = self.ilks[i]

    assert ilk.rate != 0, "Vat/ilk-not-init"

    dink_sub_flag: bool = dink < 0
    dart_sub_flag: bool = dart < 0

    
    
    if dink_sub_flag:
        urn.ink -= convert(abs(dink) , uint256) 

    else:
        urn.ink += convert(dink, uint256)
    
    if dart_sub_flag:
        urn.art -= convert(abs(dart), uint256)
        ilk.Art -= convert(abs(dart), uint256)
    else:
        urn.art += convert(dart, uint256)
        ilk.Art += convert(dart, uint256)

   


    dtab: int256 = convert(ilk.rate, int256) * dart
    tab: uint256 = ilk.rate * urn.art
    self.debt = convert(convert(self.debt, int256) + dtab, uint256)

    # Either debt has decreased, or debt ceilings are not exceeded
    assert ((dart <= 0) or ((ilk.Art * ilk.rate <= ilk.line) and (self.debt <= self.Line)))

    # urn is either less risky than before, or it is safe
    assert ((dart <= 0 and dink >= 0) or (tab <= urn.ink * ilk.spot)), "Vat/not-safe"

    # urn is either safer, or the owner consets
    assert ((dart <= 0 and dink >= 0) or self.wish(u, msg.sender))

    # Collateral src consents
    assert dink <= 0 or self.wish(v, msg.sender), "Vat/not-allowed-v"

    # debt dst consents 
    assert dart >= 0 or self.wish(w, msg.sender)

    # urn has no debt, or a non-dusty amount
    assert urn.art == 0 or tab >= ilk.dust, "Vat/dust"


    if dink_sub_flag:
        self.gem[i][v] += convert(abs(dink), uint256)
    else:
        self.gem[i][v] += convert(dink, uint256)

    if dtab < 0:
        self.dai[w] -= convert(abs(dtab), uint256)
    else:
        self.dai[w] += convert(dtab, uint256)

    
    self.urns[i][u] = urn
    self.ilks[i] = ilk


# --- CDP Fungibility ---
@external
def fork(_ilk: bytes32, _src: address, _dst: address, dink: int256, dart: int256):
    u: Urn = self.urns[_ilk][_src]
    v: Urn = self.urns[_ilk][_dst]
    i: Ilk = self.ilks[_ilk]

    if dink < 0:
        u.ink += convert(abs(dink), uint256)
        v.ink -= convert(abs(dink), uint256)
    else:
        u.ink -= convert(dink, uint256)
        v.ink += convert(dink, uint256)


    if dart < 0:
        u.art += convert(abs(dart), uint256)
        v.art -= convert(abs(dart), uint256)
    else:
        u.art -= convert(dart, uint256)
        v.art += convert(dart, uint256)

    utab: uint256 = u.art * i.rate
    vtab: uint256 = v.art * i.rate
    # Both sides consent
    assert (self.wish(_src, msg.sender) and self.wish(_dst, msg.sender)), "Vat/not-allowed"

    # Both sides safe
    assert utab <= (u.ink * i.spot), "Vat/not-safe-src"
    assert vtab <= (v.ink * i.spot), "Vat/not-safe-dst"

    # Both sides non-dusty
    assert utab >= i.dust or u.art == 0, "Vat/dust-src"
    assert vtab >= i.dust or v.art == 0, "Vat/dust-dst"

    self.urns[_ilk][_src] = u
    self.urns[_ilk][_dst] = v
    self.ilks[_ilk] = i

# --- CDP Confiscation ---
@external
def grab(i: bytes32, u: address, v:address, w: address, dink: int256, dart: int256):
    self._auth(msg.sender)
    urn: Urn = self.urns[i][u]
    ilk: Ilk = self.ilks[i]

    if dink < 0:
        urn.ink -= convert(abs(dink), uint256)
        self.gem[i][v] += convert(abs(dink), uint256)
    else:
        urn.ink += convert(dink, uint256)
        self.gem[i][v] -= convert(dink, uint256)

    if dart < 0:
        urn.art -= convert(abs(dart), uint256)
        ilk.Art -= convert(abs(dart), uint256)
    else:
        urn.art += convert(dart, uint256)
        ilk.Art += convert(dart, uint256)

    dtab: int256 = convert(ilk.rate, int256) * dart

    if dtab < 0:
        self.sin[w] += convert(abs(dtab), uint256)
        self.vice += convert(abs(dtab), uint256)
    else:
        self.sin[w] -= convert(dtab, uint256)
        self.vice -= convert(dtab, uint256)

    self.urns[i][u] = urn
    self.ilks[i] = ilk

# --- Settlement ---
@external
def heal(rad: uint256):
    u: address = msg.sender
    self.sin[u] -= rad
    self.dai[u] -= rad
    self.vice -= rad
    self.debt -= rad

@external
def suck(u: address, v:address, rad: uint256):
    self._auth(msg.sender)
    self.sin[u] += rad
    self.dai[v] += rad
    self.vice += rad
    self.debt += rad


# --- Rates ---
@external
def fold(i: bytes32, u: address, rate: int256):
    self._auth(msg.sender)
    assert self.live == 1, "Vat/not-live"
    ilk: Ilk = self.ilks[i]
    rad: int256 = convert(ilk.Art, int256) * rate
    if rate < 0:
        ilk.rate -= convert(abs(rate), uint256)
        self.dai[u] -= convert(abs(rad), uint256)
        self.debt -= convert(abs(rad), uint256)
    else:
        ilk.rate += convert(rate, uint256)
        self.dai[u] += convert(rad, uint256)
        self.debt += convert(rad, uint256)

    self.ilks[i] = ilk