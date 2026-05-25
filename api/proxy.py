from flask import Flask, jsonify, request
import urllib.request, urllib.parse, json

app = Flask(__name__)

PLAYLIST_ID = '6923484606'

@app.after_request
def cors(resp):
    resp.headers['Access-Control-Allow-Origin'] = '*'
    resp.headers['Access-Control-Allow-Methods'] = 'GET, OPTIONS'
    resp.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    return resp

@app.route('/songs')
def get_songs():
    try:
        p_req = urllib.request.Request(
            f'https://music.163.com/api/v3/playlist/detail?id={PLAYLIST_ID}',
            headers={'User-Agent': 'Mozilla/5.0', 'Referer': 'https://music.163.com/'}
        )
        p_data = json.loads(urllib.request.urlopen(p_req, timeout=15).read())
        track_ids = [t['id'] for t in p_data['playlist']['trackIds']]

        c = json.dumps([{'id': i} for i in track_ids])
        s_req = urllib.request.Request(
            f'https://music.163.com/api/v3/song/detail?c={urllib.parse.quote(c)}',
            headers={'User-Agent': 'Mozilla/5.0', 'Referer': 'https://music.163.com/'}
        )
        s_data = json.loads(urllib.request.urlopen(s_req, timeout=15).read())

        ids_json = json.dumps(track_ids)
        u_req = urllib.request.Request(
            f'https://music.163.com/api/song/enhance/player/url?ids={urllib.parse.quote(ids_json)}&br=128000',
            headers={'User-Agent': 'Mozilla/5.0', 'Referer': 'https://music.163.com/'}
        )
        u_data = json.loads(urllib.request.urlopen(u_req, timeout=15).read())

        url_map = {}
        for item in u_data['data']:
            if item.get('url') and item.get('code') == 200:
                url_map[item['id']] = item['url'].replace('http://', 'https://')

        songs = [{
            'id': s['id'],
            'name': s['name'],
            'artist': ', '.join(a['name'] for a in s['ar']),
            'url': url_map.get(s['id']),
        } for s in s_data['songs']]

        return jsonify(songs=songs, available=sum(1 for s in songs if s['url']), total=len(songs))
    except Exception as e:
        return jsonify(error=str(e)), 500

@app.route('/urls')
def get_urls():
    ids_str = request.args.get('ids', '')
    if not ids_str:
        return jsonify(error='Missing ids'), 400
    try:
        id_arr = [int(i) for i in ids_str.split(',')]
        ids_json = json.dumps(id_arr)
        u_req = urllib.request.Request(
            f'https://music.163.com/api/song/enhance/player/url?ids={urllib.parse.quote(ids_json)}&br=128000',
            headers={'User-Agent': 'Mozilla/5.0', 'Referer': 'https://music.163.com/'}
        )
        u_data = json.loads(urllib.request.urlopen(u_req, timeout=10).read())
        result = {}
        for item in u_data['data']:
            if item.get('url') and item.get('code') == 200:
                result[item['id']] = item['url'].replace('http://', 'https://')
        return jsonify(result)
    except Exception as e:
        return jsonify(error=str(e)), 500
