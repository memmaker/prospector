#!/usr/bin/env python3
"""Writes the in-page game guide (stdout -> dist/help.html, web/build.sh).

The game content comes from the key guides in ~/Desktop/Games/Roguelikes/Docs
(build-docs.py + guides.py, entry prospector.html), as for the other games;
only the web-specific parts are written here."""
import html, importlib.util, os, sys

DOCS = os.path.expanduser('~/Desktop/Games/Roguelikes/Docs')
PAGE = 'prospector.html'
sys.path.insert(0, DOCS)
spec = importlib.util.spec_from_file_location('build_docs', os.path.join(DOCS, 'build-docs.py'))
docs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(docs)
from guides import GUIDES, SAVING   # noqa: E402

game = next(g for g in docs.GAMES if g['file'] == PAGE)
info = dict(game['info'])
esc, kbd = html.escape, docs.kbd

KEY_HINTS = [('Enter', 'Menu of all commands on this screen'), ('# / ~', 'Explore (planet) / fly to an unvisited system (space)'),
             ('< / >', 'Walk to the ship, stairs or portal; in space fly to a planet or station'),
             ('E', 'Equipment with a cursor: Enter = what you can do with the item'),
             ('?', "The game's help: manual, keybindings, configuration"), ('S', 'Save and quit')]


def dl(items):
    return '<dl>' + ''.join(f'<dt>{kbd(k)}</dt><dd>{esc(d)}</dd>' for k, d in items) + '</dl>'


def section(anchor, title, body):
    return f'<h2 id="h-{anchor}">{esc(title)}</h2>{body}'


toc = [('about', 'About the game'), ('keys', 'Keyboard controls'), ('saving', 'Saving your game'), ('tips', 'Tips'),
       ('guide', "New player's guide"), ('web', 'Playing in the browser'), ('manual', 'Manual'), ('version', 'About this version')]
parts = ['<p>' + esc(game['tagline']) + '</p><ul class="toc">' +
         ''.join(f'<li><a href="#h-{a}">{esc(t)}</a></li>' for a, t in toc) + '</ul>']
parts.append(section('about', 'About the game', info['About the game']))
ess = ''.join(f'<div class="box"><h3>{esc(cat)}</h3>{dl(items)}</div>' for cat, items in game['essentials'])
all_keys = game['all']()
full = ''.join(f'<div>{kbd(k)}<span>{esc(d)}</span></div>' for k, d in all_keys)
parts.append(section('keys', 'Keyboard controls',
                     '<div class="box key"><h3>The keys to remember</h3>' + dl(KEY_HINTS) + '</div>'
                     '<h3>Essential keys</h3><div class="grid">' + ess + '</div>'
                     '<details><summary>Complete key list (' + str(len(all_keys)) + ' commands)</summary>'
                     '<div class="all">' + full + '</div></details>'))
parts.append(section('saving', 'Saving your game', SAVING[PAGE]))
parts.append(section('tips', 'Tips', info['Tips']))
parts.append(section('guide', "New player's guide", ''.join(f'<h3>{esc(t)}</h3>{b}' for t, b in GUIDES[PAGE])))
parts.append(section('web', 'Playing in the browser', info['In the browser']))
parts.append(section('manual', 'Manual',
                     '<p>The game\'s manual by Matthias Mennel (2011; some keys changed later, the lists above are current): '
                     '<a href="Manual.pdf" target="_blank" rel="noopener">open Manual.pdf</a>.</p>'
                     '<iframe src="Manual.pdf" title="Prospector manual" loading="lazy"></iframe>'))
parts.append('<h2 id="h-version">About this version</h2><ul>'
             '<li>Based on <strong>Prospector R197</strong> by Matthias Mennel: the Google Code svn trunk at r197 (2014-12-28, '
             '<a href="https://code.google.com/archive/p/rlprospector/source">code.google.com/archive/p/rlprospector</a>) '
             'with the data files of the author\'s R197 release (<code>R197prospector_l.zip</code>).</li>'
             '<li>Our changes (FreeBASIC → WebAssembly with an own graphics driver, explore and stairs walking, command menu, '
             'item menus, windows, sound, bug fixes): <a href="https://github.com/memmaker/prospector">github.com/memmaker/prospector</a> '
             '(first commits = the untouched source and data).</li>'
             '<li>Credits: game by Matthias Mennel (zlib licence); graphics by David Gervais and Deon, used with their permission.</li></ul>')
print('\n'.join(parts))
