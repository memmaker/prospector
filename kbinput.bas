
function keyin(byref allowed as string="" , blocked as short=0)as string
    'RVIP: global screens (logbook, equipment, roster...) open from nested prompts
    'only two deep; random keys nested them until the stack overflowed (ASan)
    static depth as short
    dim k as string
    depth+=1
    if depth>2 and blocked=0 then blocked=1
    k=rv_keyin0(allowed,blocked)
    depth-=1
    return k
end function

function rv_keyin0(byref allowed as string="" , blocked as short=0)as string
    dim key as string
    dim as string text
    static as byte recording
    static as byte seq
    static as ZString*4 comseq
    static as ZString*4 lastkey
    dim as short a,b,i,tog1,tog2,tog3,tog4,ctr,f,it,debug
    dim as string control
    dim as short rvmode=rv_menumode 'RVIP: nested keyin calls (menus) get 0
    rv_menumode=0
    if rvmode>0 then rv_preitem=0
    rv_webui(rvmode)
    if walking<>0 then sleep 50
    flip
    if _debug>0 and allowed<>"" then allowed &="_"
    if _test_disease=1 and allowed<>"" then allowed="#"&allowed
    if player.dead>0 and allowed<>"" then allowed=allowed &" "
    
    do 
        control=""
        do        
            If (ScreenEvent(@evkey)) Then
'                
'if evkey.ascii=0 and evkey.scancode=23 or evkey.ascii=asc(key_extended) then
'                    if evkey.type=EVENT_KEY_PRESS or evkey.type=EVENT_KEY_REPEAT THEN
'                        if evkey.scancode=23 then control="\C"
'                        if evkey.ascii=asc(key_extended) then control=key_extended
'                    else
'                        control=""
'                    endif
'                endif
                Select Case evkey.type
                    case EVENT_KEY_REPEAT
                        while screenevent(@evkey)
                        wend
                        key=lastkey
                    Case (EVENT_KEY_PRESS)
                        if debug =1 then
                            locate 1,1
                            print evkey.scancode &":"& evkey.ascii &":"&EVENT_KEY_PRESS &":"&EVENT_KEY_REPEAT
                        endif
                        select case evkey.scancode
                        case sc_down
                            key = key_south
                        case sc_up
                            key = key_north
                        case sc_left
                            key = key_west
                        case sc_right
                            key = key_east
                        case sc_home
                            key = key_nw
                        case sc_pageup
                            key = key_ne
                        case sc_end
                            key = key_sw
                        case sc_pagedown
                            key = key_se
                        case sc_escape
                            key=key__esc
                        case sc_enter
                            key=key__enter
                        case sc_pageup
                            key=key_pageup
                        case sc_pagedown
                            key=key_pagedown
                        case 120 'RVIP: web page Tiles/Text button (rv_key(120,0)), main prompts only
                            if rvmode>0 then
                                rv_toggletiles
                                return ""
                            endif
                        'case sc_control
                        '    control="\C"
                        case else
                            if evkey.ascii<=26 then
                                key="\C"&chr(evkey.ascii+96)
                            else
                                if len(chr(evkey.ascii))>0 then key = chr(evkey.ascii)
                            endif
                        end select
                    
                    end select
                endif            
            sleep 1
        loop until key<>"" or walking<>0 or (allowed="" and player.dead<>0) or just_run<>0
        lastkey=key    
        if key<>"" then 
            walking=0 
            autofire_target.m=0
        endif
        if key=key__enter and rvmode>0 then 'RVIP: command menu; the chosen key runs as if typed
            key=rv_cmdmenu(allowed,rvmode)
            if key="" then return ""
        endif
        
        if blocked>=97 then
            if _debug>0 then dprint key &":K"
            if (asc(key)>=97 and asc(key)<=blocked) then return key
        endif
        if blocked=0 or blocked>=97 then
                        
            if _debug>0 and key="\Ci" then
                dprint "Itemdump"
                f=freefile
                open "itemdump.txt" for output as #f
                for i=0 to lastitem
                    print #f,i &";"&item(i).desig &";"&item(i).w.s &"m:"& item(i).w.m &"C:"&cords(item(i).w)
                next
                close #f
            endif
            
            if _debug=-1 and key="�" then
                for x=0 to 60
                    for y=0 to 20
                        planetmap(x,y,player.map)=abs(planetmap(x,y,player.map))
                    next
                next
            endif
            
            if _debug>0 and key="�" then
                dprint "Fleetdump"
                f=freefile
                open "fleets.csv" for output as #f
                for i=0 to lastfleet
                    print #f,i &";"& fleet(i).ty  &";"& fleet(i).count  &";"& cords(fleet(i).c)
                next
                close #f
            endif
                
            
            if _debug>0 and key=key_testspacecombat then
                spacecombat(fleet(rnd_range(6,lastfleet)),9)
            endif
            
            if key=key_awayteam then
                if location=lc_onship then
                    showteam(0)
                else
                    showteam(1)
                endif
                return ""
            endif
            
            if key=key_accounting then
                textbox(income_expenses,2,2,45,11,1)
                no_key=keyin
                return ""
            endif
            
            if key=key_manual then
                a=menu(bg_parent,"Help/Manual/Keybindings/Configuration/Exit","",2,2)
                if a=1 then manual
                if a=2 then keybindings
                if a=3 then configuration
                return ""
            endif
            
            if key=key_messages then 
                messages
                return ""
            endif
            
            if key=key_configuration then
                configuration
                return ""
            endif
            
            if key=key_tactics then
                settactics
                return ""
            endif
            
            if key=key_shipstatus then         
                shipstatus()
                return ""
            endif
            
            if key=key_logbook and gamerunning=1 then 'RVIP: no logbook/autopilot during new-game setup (A_STAR overflow, ASan)
                logbook()
                return ""
            endif

            if key=key_equipment then 'RVIP: item list -> menu of the item's actions
                a=get_item(,,b)
                key=""
                if a>0 then key=rv_itemmenu(a,b,rvmode)
                if key="" then return ""
            endif
            
            if key=key_standing then
                show_standing()
                
                return ""
            endif
            
            if key=key_quest then
                show_quests
                return ""
            endif
            
            if key=key_quit then 
                if askyn("Do you really want to quit? (y/n)") then player.dead=6
            endif
            
        endif
        if key=key_autoinspect then
            screenset 1,1
            select case _autoinspect
                case is =0
                    _autoinspect=1
                    dprint "Autoinspect Off"
                case is =1
                    _autoinspect=0
                    dprint "Autoinspect On"                
            end select
            key=""     
        endif
        if key=key_autopickup then
            screenset 1,1
            select case _autopickup
                case is =0
                    _autopickup=1
                    dprint "Autopickup Off"
                case is =1
                    _autopickup=0
                    dprint "Autopickup On"                
            end select
            key=""     
        endif       
        if key=key_togglehpdisplay then
            screenset 1,1
            select case _HPdisplay
                case is =0
                    _HPdisplay=1
                    dprint "Hp display now displays icons"
                case is =1
                    _HPdisplay=0
                    dprint "Hp display now displays HPs"
            end select
            key=""
        endif
        if key="$" and dbshow_factionstatus=1 then
            
            for a=0 to 7
                text="Faction "&a
                for b=0 to 7
                    text=text &":"&faction(a).war(b)
                next
                dprint text
            next
        endif
        if len(allowed)>0 and key<>key__esc and key<>key__enter and getdirection(key)=0 then
            if instr(allowed,key)=0 and walking=0 then 
                'keybindings(allowed)
                key=""
            endif
        endif
    loop until key<>"" or walking <>0 or just_run<>0
    if just_run<>0 then 
        if just_run>0 then just_run-=1
        if key=key__esc then just_run=0
    endif
    comstr.reset
    return key
end function

function cursor(target as _cords,map as short,osx as short,osy as short=0,radius as short=0) as string
    dim key as string
    dim as _cords p2
    dim as short border,eo,x
    if configflag(con_tiles)=1 then
        set__color( 11,11)
        draw string (target.x*_fw1,target.y*_fh1)," ",,font1,custom,@_col
    else
        x=target.x-osx
        if x<0 then x+=61
        if x>60 then x-=61
        if x>=0 and x<=_mwx then put ((x)*_tix,(target.y-osy)*_tiy),gtiles(85),trans
    endif
    key=keyin
    if map>0 then
        border=0
        if planets(map).depth=0 then
            eo=4
        else
            eo=0
        endif
    endif
    if map<=0 then border=1
    'dprint ""&planetmap(target.x,target.y,map)
    if map>0 then
        if planets(map).depth=0 then
            if target.x<0 then target.x=60
            if target.x>60 then target.x=0
        else
            if target.x<0 then target.x=0
            if target.x>60 then target.x=60
        endif
        if target.y<0 then target.y=0
        if target.y>20 then target.y=20
        if planetmap(target.x,target.y,map)<0 then
            if configflag(con_tiles)=0 then
                put ((target.x-osx)*_tix,(target.y-osy)*_tiy),gtiles(0),trans
            else
                set__color( 0,0)
                draw string (target.x*_fw1,target.y*_fh1)," ",,font1,custom,@_col
            endif
        else
            if target.x>=0 and target.y>=0 and target.x<=60 and target.y<=20 then dtile(target.x-osx,target.y,tiles(planetmap(target.x,target.y,map)),1)
        endif
    else
        if configflag(con_tiles)=0 then
            put ((target.x-osx)*_tix,(target.y-osy)*_tiy),gtiles(0),trans
        else
            set__color( 0,0)
            draw string (target.x*_fw1,target.y*_fh1)," ",,font1,custom,@_col
        endif
    endif
    set__color( 11,0)
    p2=target
    target=movepoint(target,getdirection(key),eo,border)
    if radius>0 and distance(target,awayteam.c,eo)>radius then target=p2
    return key
end function

function gettext(x as short, y as short, ml as short, text as string,pixel as short=0) as string
    dim as short l,lasttimer
    dim key as string
    dim p as _cords
    l=len(text)
    if pixel=0 then
        x=x*_fw2
        y=y*_fh2
    endif
    if l>ml and text<>"" then
        text=left(text,ml-1)
        l=ml-1
    endif
    do 
            
        key=""
        set__color( 11,0)
        draw string (x,y), text &"_ ",,font2,custom,@_col
        do
            do
                sleep 1
                lasttimer+=1
                if lasttimer>100 then
                    draw string (x,y), text &"  ",,font2,custom,@_col
                else
                    draw string (x,y), text &"_ ",,font2,custom,@_col
                endif
                if lasttimer>200 then lasttimer=0
            loop until screenevent(@evkey)
            
            if evkey.type=EVENT_KEY_press then
                if evkey.ascii=asc(key__esc) then key=key__esc
                if evkey.ascii=8 then key=chr(8)
                if evkey.ascii=32 then key=chr(32)
                if evkey.ascii=asc(key__enter) then key=key__enter
                if evkey.ascii>32 and evkey.ascii<123 then key=chr(evkey.ascii)
            endif
        loop until key<>""  
        
        if key=chr(8) and l>=1 then
           l=l-1
           text=left(text,len(text)-1)
           if text=chr(8) then text=""
        endif
        if l<ml and key<>key__enter and key<>chr(8) and key<>key__esc then
            text=text &key
            l=l+1
        endif
        if l>ml then 
            l=ml
            text=left(text,ml)
        endif
        
    loop until key=key__enter or key=key__esc
    if key=key__esc or l<1 then
    endif
    if len(text)=0 then text=""
    if text=key__enter or text=key__esc or text=chr(8) then text=""
    dprint text,15
    return text
end function

function getnumber(a as integer,b as integer, e as integer) as integer
    dim key as string
    dim buffer as string
    dim as integer c,d,i
    dim p as _cords
    screenset 1,1
    dprint ""
    p=locEOL
    c=numfromstr((gettext(p.x,p.y,46,"")))
    if c>b then c=b
    if c<a then c=e
    return c
    
end function    

function keyplus(key as string) as short
    dim r as short
    if key=key__up or key=key__lt or key=key_south or key="+" then r=-1
    return r
end function

function keyminus(key as string) as short
    dim r as short
    if key=key__dn or key=key__rt or key=key_north or key="-" then r=-1
    return r
end function

function getdirection(key as string) as short
    dim d as short
    if key=key_south then return 2
    if key=key_north then return 8
    if key=key_east then return 6
    if key=key_west then return 4
    if key=key_nw then return 7
    if key=key_ne then return 9
    if key=key_se then return 3
    if key=key_sw then return 1
    if key=key__up then return 8
    if key=key__dn then return 2
    if key=key__rt then return 6
    if key=key__lt then return 4
    return 0
end function

function askyn(q as string,col as short=11,sure as short=0) as short
    dim a as short
    dim key as ZString*2
    dprint (q,col)
    do
        key=keyin
        displaytext(_lines-1)=displaytext(_lines-1)&key
        if key <>"" then 
            dprint ""
            if configflag(con_anykeyno)=0 and key<>key_yes then key="N"
        endif
    loop until key="N" or key="n" or key=" " or key=key__esc or key=key__enter or key=key_yes  
    
    if key=key_yes or key=key__enter then a=-1
    if key<>key_yes and sure=1 then a=askyn("Are you sure? Let me ask that again:" & q)
    if key=key_yes then 
        dprint "Yes.",15
    else
        dprint "No.",15
    endif
    return a
end function

function menu(bg as byte,te as string, he as string="", x as short=2, y as short=2, blocked as short=0, markesc as short=0,st as short=-1,pick as short=0) as short
    ' 0= headline 1=first entry
    dim as short blen
    dim as string text,help
    dim lines(63) as string
    dim helps(63) as string
    dim shrt(63) as string
    dim as string key,delhelp
    dim a as short
    dim b as short
    dim c as short
    static loca as short
    dim e as short
    dim l as short
    dim hfl as short
    dim hw as short
    dim lastspace as short
    dim tlen as short
    dim longest as short
    dim as short ofx,l2,longestbox,longesthelp,backpic,offset
    backpic=rnd_range(1,_last_title_pic)
    
    dim as any ptr logo
    if bg=bg_title then
        logo=bmp_load("graphics/prospector.bmp")
    endif
    text=te
    help=he
    b=len(text)
    if loca=0 then loca=1
    c=0
    text=text &"/"
    do
        tlen=instr(text,"/")
        lines(c)=left(text,tlen-1)
        text=mid(text,tlen+1)
        c=c+1
    loop until len(text)<=0
    c=c-1
    if help<>"" then
        if right(help,len(help)-1)<>"/" then help=help &"/"
        hfl=1
        e=0
        b=len(help)
        do
            tlen=instr(help,"/")
            helps(e)=left(help,tlen-1)
            'if len(helps(e))>len(delhelp) then delhelp=space(len(helps(e)))
            help=mid(help,tlen+1)
            e=e+1
        loop until len(help)<=0
        e=0
    endif
    
    if loca>c then loca=c
    b=0
    for a=0 to c
        shrt(a)=chr(96+b+a)
        if getdirection(lcase(shrt(a)))>0 or getdirection(lcase(shrt(a)))>0 or val(shrt(a))>0 or ucase(shrt(a))=ucase(key_awayteam) then
            do 
                b+=1
                shrt(a)=chr(96+b+a)
            loop until getdirection(lcase(shrt(a)))=0 and getdirection(shrt(a))=0 and val(shrt(a))=0
        endif
        if len(trim(lines(a)))>longest then longest=len(trim(lines(a)))
    next
    for a=0 to c
        lines(a)=lines(a)&space(longest-len(lines(a)))
    next
    hw=_mwx*_fw1-((longest)*_fw2)-(3+x)*_fw1
    hw=hw/_fw2
    
    for a=0 to c
        longesthelp=1
        l2=textbox(helps(a),ofx,2,hw,15,1,,longesthelp)
        if l2>longestbox then longestbox=l2
    next
    
    if longestbox>20 or (longestbox/hw)>2 or hw<8 then
        hw=_screenx-((4+x)*_fw1)-((longest)*_fw2)
        hw=hw/_fw2
    endif
    'if hw>longesthelp then hw=longesthelp
    ofx=x+4+(longest*_fw2/_fw1)
    e=0
    do        
        if bg<>bg_noflip then
            screenset 0,1
            set__color(15,0)
            cls
            select case bg
            case bg_title
                background(backpic &".bmp") 
                if logo<>NULL then
                    put (39,69),logo,trans
                else
                    draw string(26,26),"PROSPECTOR",,titlefont,custom,@_col
                endif
            case bg_ship
                display_ship
            case bg_shiptxt
                display_ship
                dprint ""
            case bg_shipstars
                display_stars(1)
                display_ship
            case bg_shipstarstxt
                display_stars(1)
                display_ship
                dprint ""
            case bg_awayteam
                display_awayteam(0)
            case bg_awayteamtxt
                display_awayteam(0)
                dprint ""
            case bg_randompic
                background(backpic &".bmp")
            case bg_randompictxt
                background(backpic &".bmp")
                dprint ""
            case bg_stock
                display_ship
                display_stock
                portfolio(17,2)
                dprint ""
            case bg_roulette
                drawroulettetable
                display_ship
                dprint ""
            case is>=bg_trading
                display_ship()
                displaywares(bg-bg_trading)
                dprint ""
            end select
            if _debug>0 then dtile(0,0,tiles(229),1)
            if _debug>0 then dtile(1,0,tiles(230),1)
            if _debug>0 then dtile(2,0,tiles(231),1)
            if _debug>0 then dtile(3,0,tiles(232),1)
        
        endif
        set__color( 15,0)
        draw string(x*_fw1,y*_fh1), lines(0)&space(3),,font2,custom,@_col
        
        for a=1 to c
            if loca=a then 
                if hfl=1 and loca<=c and helps(a)<>"" then blen=textbox(helps(a),ofx,2,hw,15,1,,,offset)
                set__color( 15,5)
            else
                set__color( 11,0)
            endif
            draw string(x*_fw1,y*_fh1+a*_fh2),shrt(a) &") "& lines(a),,font2,custom,@_col
        next
        
        if bg<>bg_noflip then 
            flip
        else
            dprint ""
        endif
        rv_onmap=0 'RVIP: a menu is a pop-up, even over the map
        if player.dead=0 then 
            if blocked=0 then
                key=keyin(,96+c)
            else
                key=keyin(,1)
            endif
        endif
        if _debug>2112 then dprint key
        if hfl=1 then 
            for a=1 to blen
                set__color( 0,0)
                draw string(ofx*_fw1,y*_fh1+(a-1)*_fh2), space(hw),,font2,custom,@_col
            next
        endif
        if helps(loca)<>"" then
            if key="+" then offset+=1
            if key="-" then offset-=1
        endif
        if getdirection(key)=8 then loca=loca-1
        if getdirection(key)=2 then loca=loca+1
        
        if loca<1 then loca=c
        if loca>c then loca=1
        if key=key__enter then e=loca
        for a=0 to c
            if key=lcase(shrt(a)) then loca=a: e=iif(pick<>0 and a>0,a,e) 'RVIP: letter chooses
        next
        if key=key__esc or player.dead<>0 then e=c
    loop until e>0 
    if key=key__esc and markesc=1 then e=-1
    set__color( 0,0)
    for a=0 to c
        locate y+a,x
        draw string(x*_fw1,y*_fh1+a*_fh2), space(59),,font2,custom,@_col
    next
    set__color( 11,0)
    cls
    screenset 1,1
    return e
end function

'RVIP stage 3: Enter menu and item menus. The game's own menu() draws them; the chosen key runs through the game's own handlers.
function rv_kname(k as string) as string
    if left(k,2)="\C" then return "^"&mid(k,3)
    return k
end function

function rv_cmdadd(byref mt as string, byref mk as string, k as string, label as string, allowed as string="") as short
    'adds one entry (key shown in front) when k is allowed at this prompt; allowed="" = always
    if k="" or (allowed<>"" and instr(allowed,k)=0) then return 0
    mt &= "/" & rv_kname(k) & space(4-len(rv_kname(k))) & label
    mk &= k & chr(1)
    return 0
end function

function rv_cmdkey(mk as string, i as short) as string
    'i-th key (1-based) of a chr(1)-separated list
    dim as short a,p=1,q
    for a=1 to i
        q=instr(p,mk,chr(1))
        if q=0 then return ""
        if a=i then return mid(mk,p,q-p)
        p=q+1
    next
    return ""
end function

function rv_cmdmenu(allowed as string, mode as short) as string
    'mode 1 = space (explore_space), 2 = planet surface / ship or station interior (explore_planet)
    dim as string mt(4),mk(4)
    dim as short g,a,bg
    mt(1)="Move and explore": mt(2)="Actions": mt(3)="Ship and crew": mt(4)="Game"
    rv_cmdadd(mt(1),mk(1),key_walk,"walk in a direction",allowed)
    rv_cmdadd(mt(1),mk(1),key_wait,"wait",allowed)
    if mode=1 then
        rv_cmdadd(mt(1),mk(1),key_autoexplore,"explore: fly to an unvisited system (also ~)",allowed)
        rv_cmdadd(mt(1),mk(1),">","fly to the nearest planet or station (again: land or dock)",allowed)
        rv_cmdadd(mt(1),mk(1),"<","about < and > in space",allowed)
        rv_cmdadd(mt(1),mk(1),key_la,"land on a planet or enter a wormhole",allowed)
        rv_cmdadd(mt(1),mk(1),key_tala,"land at a chosen spot",allowed)
        rv_cmdadd(mt(1),mk(1),key_dock,"dock at a station",allowed)
        rv_cmdadd(mt(2),mk(2),key_sc,"scan planets",allowed)
        rv_cmdadd(mt(2),mk(2),key_fi,"attack",allowed)
        rv_cmdadd(mt(2),mk(2),key_tow,"tow a ship"&iif(artflag(25)>0," or wormhole generator",""),allowed)
        rv_cmdadd(mt(2),mk(2),key_drop,"launch a probe",allowed)
        rv_cmdadd(mt(2),mk(2),key_ra,"radio",allowed)
        rv_cmdadd(mt(2),mk(2),key_comment,"comment on the map",allowed)
        rv_cmdadd(mt(2),mk(2),key_optequip,"armor choice for the away team",allowed)
    else
        rv_cmdadd(mt(1),mk(1),key_autoexplore,"autoexplore (also ~)",allowed)
        rv_cmdadd(mt(1),mk(1),"<","go up: walk to stairs, portal or the ship (again: use it)",allowed)
        rv_cmdadd(mt(1),mk(1),">","go down: walk to known stairs, tunnel or portal (again: use it)",allowed)
        rv_cmdadd(mt(1),mk(1),key_la,"launch (at the ship)",allowed)
        if awayteam.movetype>=2 then rv_cmdadd(mt(1),mk(1),key_ju,"jetpack jump",allowed)
        if awayteam.teleportrange>0 then rv_cmdadd(mt(1),mk(1),key_te,"teleport",allowed)
        rv_cmdadd(mt(2),mk(2),key_ex,"examine",allowed)
        rv_cmdadd(mt(2),mk(2),key_fi,"fire",allowed)
        rv_cmdadd(mt(2),mk(2),key_autofire,"autofire",allowed)
        rv_cmdadd(mt(2),mk(2),key_gr,"throw grenade",allowed)
        rv_cmdadd(mt(2),mk(2),key_he,"use medpack",allowed)
        rv_cmdadd(mt(2),mk(2),key_pickup,"pick up",allowed)
        rv_cmdadd(mt(2),mk(2),key_drop,"drop",allowed)
        rv_cmdadd(mt(2),mk(2),key_inspect,"inspect",allowed)
        rv_cmdadd(mt(2),mk(2),key_co,"chat",allowed)
        rv_cmdadd(mt(2),mk(2),key_of,"offer",allowed)
        rv_cmdadd(mt(2),mk(2),key_oxy,"open or close helmet",allowed)
        rv_cmdadd(mt(2),mk(2),key_close,"close door",allowed)
        rv_cmdadd(mt(2),mk(2),key_report,"bioreport",allowed)
        rv_cmdadd(mt(2),mk(2),key_ra,"radio",allowed)
    endif
    rv_cmdadd(mt(3),mk(3),key_shipstatus,"ship status")
    rv_cmdadd(mt(3),mk(3),key_awayteam,"crew roster")
    rv_cmdadd(mt(3),mk(3),key_equipment,"equipment and inventory")
    rv_cmdadd(mt(3),mk(3),key_tactics,"tactics")
    rv_cmdadd(mt(3),mk(3),key_logbook,"logbook")
    rv_cmdadd(mt(3),mk(3),key_quest,"missions")
    rv_cmdadd(mt(3),mk(3),key_standing,"faction standing")
    rv_cmdadd(mt(3),mk(3),key_accounting,"income and expenses")
    rv_cmdadd(mt(3),mk(3),key_messages,"message log")
    rv_cmdadd(mt(4),mk(4),key_manual,"help")
    rv_cmdadd(mt(4),mk(4),key_configuration,"configuration")
    rv_cmdadd(mt(4),mk(4),key_autoinspect,"toggle autoinspect")
    rv_cmdadd(mt(4),mk(4),key_autopickup,"toggle autopickup")
    rv_cmdadd(mt(4),mk(4),key_togglehpdisplay,"toggle HP display")
    rv_cmdadd(mt(4),mk(4),key_save,"save and quit",allowed)
    rv_cmdadd(mt(4),mk(4),key_quit,"quit without saving",allowed)
    if mode=1 then bg=bg_shipstarstxt else bg=bg_awayteamtxt
    do
        g=menu(bg,"Commands/Move and explore/Actions/Ship and crew/Game","",2,2,0,1,,1)
        if g<1 then return ""
        a=menu(bg,mt(g),"",2,2,0,1,,1)
        if a>=1 then return rv_cmdkey(mk(g),a)
    loop 'Esc in a group goes back to the groups
end function

function rv_itemmenu(i as short, num as short, mode as short) as string
    'actions of item i (num = stack size from get_item); mode as rv_cmdmenu, 0 = elsewhere (examine / assign only)
    dim as string mt,mk,k
    dim as short a,bg
    mt=item(i).desig
    if mode=2 then
        if item(i).ty=11 then rv_cmdadd(mt,mk,key_he,"use")
        if item(i).ty=7 then rv_cmdadd(mt,mk,key_gr,"throw")
        rv_cmdadd(mt,mk,key_drop,"drop")
    endif
    if mode=1 and item(i).ty=55 then rv_cmdadd(mt,mk,key_drop,"launch")
    if item(i).ty>=2 and item(i).ty<=4 then rv_cmdadd(mt,mk,key_awayteam,"assign to a crew member (then s)")
    rv_cmdadd(mt,mk,key_ex,"examine")
    select case mode
    case 1: bg=bg_shipstarstxt
    case 2: bg=bg_awayteamtxt
    case else: bg=bg_noflip
    end select
    a=menu(bg,mt,"",2,2,0,1,,1)
    if a<1 then return ""
    k=rv_cmdkey(mk,a)
    rv_preitem=i
    rv_prenum=num
    if k=key_awayteam then 'the roster's "s set item" takes the preselected item
        if location=lc_onship then showteam(0) else showteam(1)
        rv_preitem=0
        return ""
    endif
    if k=key_ex then
        rv_preitem=0
        dprint item(i).ldesc
        no_key=keyin()
        return ""
    endif
    return k 'runs as if typed: get_item / findbest return rv_preitem
end function

'RVIP: the game's own ASCII option (configflag(con_tiles), config.txt tiles:),
'switched from the web page. Sets up the screen as a restart with the new
'config would (load_config + load_fonts in main.bas), then the caller redraws.
sub rv_toggletiles()
    configflag(con_tiles)=1-configflag(con_tiles)
    if configflag(con_tiles)=0 then
        _mwx=gt_mwx
    else
        _mwx=60
    endif
    save_config(configflag(con_tiles))
    load_fonts
    if configflag(con_tiles)=0 and gt_no(1)=0 then load_tiles 'ASCII start with sysmaptiles off: never loaded
    cls
end sub

'RVIP: the web page's windows (port/webgfx.c, web/prospector.js). At a main
'prompt (mode 1 space, 2 planet/station) the page shows the map, message and
'sidebar parts of the screen in their own windows; anything else (menus,
'dialogs, title, combat) is shown whole over the map, one-line questions
'over the main screen (rv_onmap, types.bas) as a prompt line over the map; the Map
'window follows the ship / away team (hx,hy) when it is smaller than the map. The
'inventory goes as text, coloured by kind (the game's own list has one colour;
'Angband-style colours by category, itemcat()).
sub rv_webui(rvmode as short)
    dim as _items inv(1024)
    dim as short invn(1024)
    dim as short last,i,c,col
    dim as string t
    static as short hx,hy 'ship / away team cell centre on the map part (px), kept for nested prompts
    if rvmode=1 then
        hx=(player.c.x-player.osx)*_fw1+_fw1\2
        hy=(player.c.y-player.osy)*_fh1+_fh1\2
    elseif rvmode=2 then
        hx=(awayteam.c.x-calcosx(awayteam.c.x,planets(player.map).depth))*_fw1+_fw1\2
        hy=awayteam.c.y*_fh1+_fh1\2
    endif
    if rvmode>0 then rv_onmap=1
    rv_regions(rvmode,(_mwx+1)*_fw1,22*_fh1,fix((22*_fh1)/_fh2)*_fh2,sidebar,hx,hy,iif(rvmode=0 and rv_onmap<>0,1,0))
    if rvmode=0 then exit sub
    last=get_item_list(inv(),invn())
    for i=1 to last
        col=15 'headline
        if invn(i)>0 then
            col=11
            for c=1 to 10
                if check_item_filter(inv(i).ty,c) then
                    select case c
                    case 1: col=10 'transport
                    case 2,4: col=7 'weapons
                    case 3: col=6 'armor
                    case 5: col=9 'medical
                    case 6: col=12 'grenades
                    case 7: col=13 'artwork
                    case 8: col=14 'resources
                    case 9: col=11 'equipment
                    case 10: col=3 'ship equipment
                    end select
                    exit for
                endif
            next
        endif
        t &= hex(palette_(col) and &hFFFFFF,6) & " "
        if invn(i)>1 then
            t &= "  " & invn(i) & " " & trim(inv(i).desigp)
        elseif invn(i)=1 then
            t &= "  " & trim(inv(i).desig)
        else
            t &= trim(inv(i).desig)
        endif
        t &= chr(10)
    next
    rv_inv(strptr(t))
end sub
