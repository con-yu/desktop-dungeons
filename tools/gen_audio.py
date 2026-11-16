#!/usr/bin/env python3
"""程序合成 8-bit 音效与循环 BGM，输出到 assets/audio/。
不依赖任何第三方库，仅用标准库 wave/math/random。
用法: python3 tools/gen_audio.py
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")

NOTE = {
    "C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61, "G3": 196.00, "A3": 220.00, "B3": 246.94,
    "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.00, "A4": 440.00, "B4": 493.88,
    "C5": 523.25, "D5": 587.33, "E5": 659.25, "F5": 698.46, "G5": 783.99, "A5": 880.00, "B5": 987.77,
    "C6": 1046.50, "E6": 1318.51, "G6": 1567.98,
}


def write_wav(name, samples):
    path = os.path.join(OUT, name + ".wav")
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = 0.92 / peak if peak > 0.92 else 1.0
    data = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s * scale)) * 32767)
        data += struct.pack("<h", v)
    w = wave.open(path, "w")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(bytes(data))
    w.close()
    print("  %-16s %5.2fs" % (name, len(samples) / SR))


def osc(kind, freq, dur, vol=0.5, duty=0.5, decay=6.0, slide=None, vibrato=0.0):
    n = int(SR * dur)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = freq * (slide ** (t / dur)) if slide else freq
        if vibrato:
            f *= 1.0 + vibrato * math.sin(2 * math.pi * 6.0 * t)
        ph += f / SR
        if kind == "square":
            v = 1.0 if (ph % 1.0) < duty else -1.0
        elif kind == "tri":
            v = 4.0 * abs((ph % 1.0) - 0.5) - 1.0
        elif kind == "saw":
            v = 2.0 * (ph % 1.0) - 1.0
        else:
            v = math.sin(2 * math.pi * ph)
        env = math.exp(-decay * t) * min(1.0, t / 0.004)
        out.append(v * env * vol)
    return out


def noise(dur, vol=0.5, decay=10.0, lp=0.4, hp=0.0):
    n = int(SR * dur)
    out = []
    prev = 0.0
    prev_hp = 0.0
    for i in range(n):
        t = i / SR
        s = random.uniform(-1.0, 1.0)
        prev = prev * (1 - lp) + s * lp
        val = prev
        if hp > 0:
            prev_hp = prev_hp * (1 - hp) + val * hp
            val = val - prev_hp
        out.append(val * math.exp(-decay * t) * vol)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


def seq(notes, unit=0.08, kind="square", vol=0.45, duty=0.5, decay=7.0):
    """把 (音名或频率, 时长倍数) 序列拼成一条轨。"""
    out = []
    for name, mult in notes:
        f = NOTE.get(name, name) if isinstance(name, str) else name
        out += osc(kind, f, unit * mult, vol=vol, duty=duty, decay=decay)
    return out


def pad(track, dur):
    n = int(SR * dur)
    return track + [0.0] * max(0, n - len(track))


def build_sfx():
    print("音效:")
    # 玩家挥砍命中：噪声爆破 + 低方波
    write_wav("hit", mix(noise(0.09, 0.7, 42, 0.7), pad(osc("square", 180, 0.09, 0.5, 0.5, 30, 0.8), 0.09), pad(osc("sine", 90, 0.12, 0.4, 0.5, 24), 0.12)))
    # 玩家受伤
    write_wav("hurt", mix(osc("saw", 320, 0.2, 0.5, 0.5, 12, 0.35), pad(noise(0.1, 0.35, 30, 0.5), 0.2)))
    # 击杀
    write_wav("kill", mix(noise(0.22, 0.6, 16, 0.5), pad(osc("square", 140, 0.24, 0.45, 0.5, 14, 0.5), 0.24)))
    # 升级：上行琶音
    write_wav("levelup", pad(seq([("C5", 1), ("E5", 1), ("G5", 1), ("C6", 2.5)], 0.075, "square", 0.5, 0.35, 9), 0.5))
    # 药水：上滑 + 颤音
    write_wav("potion", osc("sine", 420, 0.3, 0.55, 0.5, 6, 2.4, 0.03))
    # 金币
    write_wav("coin", pad(seq([("B5", 1), ("E6", 2)], 0.055, "square", 0.4, 0.25, 12), 0.22))
    # 脚步
    write_wav("step", noise(0.05, 0.22, 60, 0.25))
    # 火球
    write_wav("fireball", mix(noise(0.35, 0.6, 8, 0.45), pad(osc("saw", 700, 0.35, 0.35, 0.5, 7, 0.28), 0.35)))
    # 胜利
    write_wav("victory", pad(seq([("C5", 1), ("E5", 1), ("G5", 1), ("C6", 3)], 0.13, "square", 0.5, 0.4, 4), 0.75))
    # 死亡
    write_wav("death", mix(osc("square", 380, 0.7, 0.5, 0.5, 3, 0.16), pad(noise(0.4, 0.3, 7, 0.3), 0.7)))
    # 点击
    write_wav("click", osc("square", 880, 0.04, 0.3, 0.5, 60))
    # BOSS 倒下
    write_wav("boss_down", mix(osc("saw", 220, 0.8, 0.5, 0.5, 3.2, 0.3), pad(noise(0.7, 0.4, 4, 0.35), 0.8)))
    # 箭矢
    write_wav("arrow", noise(0.14, 0.4, 22, 0.75, 0.3))
    # 潜行
    write_wav("stealth", osc("tri", 560, 0.32, 0.4, 0.5, 7, 0.45))
    # 商店开门
    write_wav("shop", pad(seq([("G5", 1), ("B5", 1), ("D5", 2)], 0.09, "tri", 0.5, 0.5, 6), 0.4))


def build_music():
    print("BGM:")
    random.seed(7)

    # --- 标题：缓慢的 A 小调琶音 ---
    bar = 2.0
    total = bar * 4
    melody_notes = ["A4", "C5", "E5", "C5", "F4", "A4", "C5", "A4",
                    "C5", "E5", "G5", "E5", "G4", "B4", "D5", "B4"]
    lead = []
    step = total / len(melody_notes)
    for nm in melody_notes:
        lead += osc("tri", NOTE[nm], step, 0.30, 0.5, 3.2)
    bass_notes = ["A3", "F3", "C4", "G3"]
    bass = []
    for nm in bass_notes:
        bass += osc("sine", NOTE[nm] / 2, bar, 0.22, 0.5, 0.7)
    write_wav("music_title", mix(lead, bass))

    # --- 地牢：紧张的低音脉冲 + 方波旋律 ---
    total = 16.0
    beat = 0.5
    lead_pat = ["A4", None, "E5", None, "D5", None, "C5", "B4",
                "A4", None, "E5", None, "G5", None, "E5", None,
                "F4", None, "C5", None, "D5", None, "E5", "D5",
                "A4", None, "C5", None, "B4", None, "A4", None]
    lead = []
    for nm in lead_pat:
        if nm is None:
            lead += [0.0] * int(SR * beat)
        else:
            lead += osc("square", NOTE[nm], beat, 0.22, 0.25, 4.5)
    bass_seq = ["A3", "A3", "F3", "F3", "C4", "C4", "G3", "G3"]
    bass = []
    for nm in bass_seq:
        bass += osc("tri", NOTE[nm] / 2, total / len(bass_seq), 0.26, 0.5, 0.4)
    hats = []
    for i in range(int(total / (beat / 2))):
        hats += noise(beat / 2, 0.06, 26, 0.8, 0.5)
    track = mix(lead, bass, hats)
    write_wav("music_dungeon", track[: int(SR * total)])


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    build_sfx()
    build_music()
    print("完成 ->", OUT)
