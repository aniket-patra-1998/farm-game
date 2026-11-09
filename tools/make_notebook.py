"""Writes tools/generate_art.ipynb, the Colab notebook that paints the game's art with FLUX Klein.

Edit the notebook here, not in Colab, then run: python3 tools/make_notebook.py
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

INTRO = '# Farm game art (Colab + GitHub)\n\nPaints every piece of art the game needs with FLUX Klein, using the list, reference sketches and style\nexamples **from the GitHub repo**, and pushes the finished pieces back to the repo (`art/final/`) every\n10 pieces, with a log in `art/final/generated.json`. What\'s in the repo is what\'s done: run it again any\ntime and it only makes what\'s missing. Nothing is saved anywhere else; if Colab disconnects, at most the\nlast few unpushed pieces are made again.\n\n**Once only: a GitHub token** (lets this notebook read and push to your private repo)\n1. On GitHub: Settings → Developer settings → Personal access tokens → Fine-grained tokens → **Generate new token**.\n2. Name it `colab-art`, pick an expiry, **Repository access: Only select repositories → farm-game**.\n3. **Permissions → Repository permissions → Contents: Read and write**. Generate, and copy the token.\n4. In Colab, click the **key icon** in the left sidebar → **Add new secret** → name `GH_TOKEN`, paste the token,\n   and switch **Notebook access** on. (Your `HF_TOKEN` secret stays as it is.)\n\n**Faster, for about $7:** set `BACKEND = "api"` in cell 1 and add a Colab secret `BFL_API_KEY` (from\napi.bfl.ai). It paints 8 pieces at once, so all 812 take roughly 15-20 minutes, at about $0.009 a piece.\n\n**Every run**\n1. Runtime → Change runtime type → **A100 GPU** (check cell 4 prints "A100"; a T4 is much slower).\n2. Runtime → **Run all**.\n3. Leave the tab open. If it disconnects, Run all again: it carries on.'

SETTINGS = '# 1. Settings\nSTYLE = "painterly"\nONLY = []          # art ids to make, e.g. ["cow", "crop_wheat_ripe"]; empty = everything that\'s missing\nREDO = []          # art ids to make again even though they\'re done\nSKIP_CLASSES = []  # e.g. ["Icon", "Avatar"] to leave some kinds out for now\nSEED = 7\nBACKEND = "auto"   # "auto", "flux3" (~35 GB GPU, HF_TOKEN), "flux2" (~14 GB GPU) or "api" (BFL_API_KEY, paid, fastest)\nAPI_WORKERS = 8    # with "api": how many pieces are painted at once\nSTYLE_REFS = 3     # style examples given with each piece (fewer is faster)\nREPO = "aniket-patra-1998/farm-game"\nBRANCH = "main"\nPUSH_EVERY = 10    # push finished pieces to GitHub this often\nGIT_NAME = "Aniket"\nGIT_EMAIL = "aniketpatra001@gmail.com"'

INSTALL = '# 2. Install\n!pip -q install git+https://github.com/huggingface/diffusers.git transformers accelerate sentencepiece protobuf\n!pip -q install "rembg[gpu]" "pillow<13" requests'

REPO = '# 3. Get the repo: the list, sketches, style examples and what\'s already done\nimport os, json, subprocess, time, datetime\nRAW = "/content/raw"   # Klein\'s full pictures, on this Colab machine only (not saved)\nos.makedirs(RAW, exist_ok=True)\n\ndef secret(name):\n    try:\n        from google.colab import userdata\n        return userdata.get(name)\n    except Exception:\n        return None\n\nTOKEN = secret("GH_TOKEN")\nassert TOKEN, "Add your GitHub token as a Colab secret named GH_TOKEN with notebook access on (steps at the top)."\nREPO_DIR = "/content/farm-game"\n\ndef run(cmd, cwd=None):\n    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)\n    if r.returncode:\n        raise RuntimeError((r.stderr or r.stdout).replace(TOKEN, "***"))\n    return r.stdout\n\ndef git(*args):\n    return run(["git", *args], cwd=REPO_DIR)\n\nif not os.path.exists(REPO_DIR + "/.git"):\n    run(["git", "clone", "--depth", "1", "-b", BRANCH, f"https://x-access-token:{TOKEN}@github.com/{REPO}.git", REPO_DIR])\nelse:\n    git("pull", "--rebase", "origin", BRANCH)\ngit("config", "user.name", GIT_NAME)\ngit("config", "user.email", GIT_EMAIL)\n\nos.chdir(REPO_DIR + "/art")\nmanifest = json.load(open("manifest.json"))\nos.makedirs("final", exist_ok=True)\nmeta = json.load(open("final/sprites.json")) if os.path.exists("final/sprites.json") else {}\nlog = json.load(open("final/generated.json")) if os.path.exists("final/generated.json") else {}\nitems = [i for i in manifest["items"] if i["class"] not in SKIP_CLASSES and (not ONLY or i["id"] in ONLY)]\ntodo = [i for i in items if i["id"] in REDO or not os.path.exists(f"final/{i[\'id\']}.png")]\nprint(f"{len(manifest[\'items\'])} pieces in the list (version {manifest.get(\'version\', 1)}), "\n      f"{len(items) - len(todo)} already in the repo, {len(todo)} to make")\n\nif secret("HF_TOKEN"):\n    os.environ["HF_TOKEN"] = secret("HF_TOKEN")\nBFL_KEY = secret("BFL_API_KEY")'

MODEL = r"""
# 4. Load the model (picked by GPU)
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"
import base64, io, time, requests, torch, gc
from PIL import Image
gpu_gb = torch.cuda.get_device_properties(0).total_memory / 1e9 if torch.cuda.is_available() else 0
if BACKEND == "auto":
    BACKEND = "flux3" if gpu_gb >= 35 and os.environ.get("HF_TOKEN") else ("flux2" if gpu_gb >= 14 else "api")
name = torch.cuda.get_device_name(0) if torch.cuda.is_available() else "none"
print(f"GPU: {name}, {gpu_gb:.0f} GB -> {BACKEND}")
SMALL_GPU = BACKEND != "api" and gpu_gb < 35
if SMALL_GPU:
    print("NOTE: this isn't an A100. It works, but slower and with smaller reference images. "
          "For the best results: Runtime -> Change runtime type -> A100 GPU, then Run all again.")

def paint_size(item):
    # Paint only as big as the game needs: icons and animals at 512, crops and mid pieces at 768, big buildings at 1024.
    final = 256 * item["tiles"] * item["fill"]
    size = 512 if final <= 240 else (768 if final <= 380 else 1024)
    return min(size, 768) if SMALL_GPU else size

def refs_for(item, size):
    # The item's layout sketch first, then style examples. The farmer's other poses also get his finished idle pose.
    chain = [f"{RAW}/{item['chain']}.png"] if item.get("chain") else []
    if chain and not os.path.exists(chain[0]) and os.path.exists(f"final/{item['chain']}.png"):
        # The idle pose was made in an earlier session: use the finished cut-out from the repo, on grey.
        cut = Image.open(f"final/{item['chain']}.png").convert("RGBA")
        grey = Image.new("RGBA", (cut.width + 200, cut.height + 200), (232, 232, 232, 255))
        grey.alpha_composite(cut, (100, 100))
        grey.convert("RGB").save(chain[0])
    style = list(manifest.get("style_refs", []))[:1 if SMALL_GPU else STYLE_REFS]
    out = []
    for p in chain + list(item["refs"]) + style:
        if os.path.exists(p):
            im = Image.open(p).convert("RGB")
            im.thumbnail((min(size, 512) if SMALL_GPU else size,) * 2)  # smaller references paint faster
            out.append(im)
    return out

if BACKEND == "flux3":
    from diffusers import ModularPipeline
    pipe = ModularPipeline.from_pretrained("black-forest-labs/flux-3-image-klein")
    try:
        pipe.blocks.sub_blocks.pop("prompt_upsampler")
        pipe = pipe.blocks.init_pipeline("black-forest-labs/flux-3-image-klein")
    except Exception as e:
        print("Upsampler not removed:", e)
    pipe.load_components(dtype={"vae": torch.float32, "default": torch.bfloat16})
    pipe.to("cuda")
    if getattr(pipe, "vae", None) is not None and hasattr(pipe.vae, "enable_tiling"):
        pipe.vae.enable_tiling()

    def generate(prompt, refs, seed, size):
        args = dict(prompt=prompt, generator=torch.Generator().manual_seed(seed), output="images")
        if refs:
            args["image"] = refs
        for s in (size, 768, 512):
            if s > size:
                continue
            try:
                return pipe(**args, height=s, width=s)[0]
            except torch.OutOfMemoryError:
                print("out of memory at", s, "- trying smaller")
            finally:
                gc.collect(); torch.cuda.empty_cache()
        raise RuntimeError("out of memory even at 512")

elif BACKEND == "flux2":
    from diffusers import Flux2KleinPipeline
    pipe = Flux2KleinPipeline.from_pretrained("black-forest-labs/FLUX.2-klein-4B", torch_dtype=torch.bfloat16)
    if gpu_gb >= 22:
        pipe.to("cuda")
    else:
        pipe.enable_model_cpu_offload()

    def generate(prompt, refs, seed, size):
        args = dict(prompt=prompt, height=size, width=size, guidance_scale=1.0, num_inference_steps=4,
                    generator=torch.Generator(device="cuda").manual_seed(seed))
        if refs:
            args["image"] = refs if len(refs) > 1 else refs[0]
        try:
            return pipe(**args).images[0]
        finally:
            gc.collect(); torch.cuda.empty_cache()

else:
    assert BFL_KEY, "BACKEND is 'api' but there's no BFL_API_KEY secret."
    API = "https://api.bfl.ai/v1/flux-3-image-klein"
    HEAD = {"x-key": BFL_KEY, "accept": "application/json", "Content-Type": "application/json"}

    def generate(prompt, refs, seed, size):
        body = {"prompt": prompt, "seed": seed, "width": size, "height": size, "output_format": "png"}
        if refs:
            enc = []
            for r in refs:
                b = io.BytesIO(); r.save(b, "PNG"); enc.append(base64.b64encode(b.getvalue()).decode())
            body["images"] = enc
        for attempt in range(5):
            r = requests.post(API, headers=HEAD, json=body, timeout=60)
            if r.status_code == 429:  # too many at once: wait and retry
                time.sleep(5 * (attempt + 1)); continue
            r.raise_for_status()
            break
        poll = r.json()["polling_url"]
        while True:
            time.sleep(0.8)
            res = requests.get(poll, headers=HEAD, timeout=60).json()
            if res.get("status") == "Ready":
                return Image.open(io.BytesIO(requests.get(res["result"]["sample"], timeout=120).content))
            if res.get("status") in ("Error", "Failed", "Content Moderated", "Request Moderated"):
                raise RuntimeError(str(res))
print("ready")
"""

MAKE = r"""
# 5. Paint, cut out and size each piece, pushing to GitHub every PUSH_EVERY pieces (rerun to resume)
from concurrent.futures import ThreadPoolExecutor
from rembg import remove, new_session
session = new_session("birefnet-general", providers=["CPUExecutionProvider"])  # keeps the GPU for Klein
TILE = 256  # at 2x a tile is 256 px wide; the footprint's front corner is the image bottom
painters = ThreadPoolExecutor(API_WORKERS if BACKEND == "api" else 1)
cutters = ThreadPoolExecutor(2)  # cut-outs run on the CPU while the next piece paints

def paint(item):
    path = f"{RAW}/{item['id']}.png"
    if item["id"] in REDO or not os.path.exists(path):
        size = paint_size(item)
        common = manifest.get("commons", {}).get(item["class"], manifest["common"])
        prompt = f"{common} Subject: {item['subject']}. {manifest['styles'][STYLE]}"
        generate(prompt, refs_for(item, size), SEED, size).save(path)

def finish(item):
    # Cut out, size to the grid and record the anchor (the ground centre) for the game.
    cut = remove(Image.open(f"{RAW}/{item['id']}.png").convert("RGB"), session=session)
    cut = cut.crop(cut.getbbox())
    w = int(TILE * item["tiles"] * item["fill"])
    cut = cut.resize((w, max(1, int(cut.height * w / cut.width))), Image.LANCZOS)
    cut.save(f"final/{item['id']}.png")
    lift = 64 * item["tiles"] * item["fill"] if item["class"] in ("Crop", "Ground") or item["fill"] >= 0.95 else 0
    meta[item["id"]] = {"anchor": [cut.width / 2, cut.height - lift], "scale": 0.5}
    log[item["id"]] = {"class": item["class"], "model": BACKEND, "style": STYLE, "seed": SEED,
                       "size": paint_size(item), "made": datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M")}

def push(note):
    json.dump(meta, open("final/sprites.json", "w"), indent=1, sort_keys=True)
    json.dump(log, open("final/generated.json", "w"), indent=1, sort_keys=True)
    git("add", "art/final")
    if not git("status", "--porcelain", "art/final").strip():
        return
    git("commit", "-q", "-m", f"Art: {note} ({len(log)} generated so far) [skip ci]")
    for attempt in range(4):
        try:
            git("pull", "--rebase", "-q", "origin", BRANCH)
            git("push", "-q", "origin", BRANCH)
            print("pushed:", note)
            return
        except RuntimeError as e:
            print("push failed, retrying:", str(e)[:200]); time.sleep(10)
    print("Couldn't push; the pieces are still on this Colab machine. Run this cell again to retry.")

start = time.time()
failed, made, in_a_row, stop = [], 0, 0, False
for first in range(0, len(todo), PUSH_EVERY):
    chunk = todo[first:first + PUSH_EVERY]
    painting = [(item, painters.submit(paint, item)) for item in chunk]
    cutting = []
    for item, job in painting:
        try:
            job.result()
            cutting.append((item, cutters.submit(finish, item)))
            in_a_row = 0
        except Exception as e:
            failed.append(item["id"]); in_a_row += 1
            print("FAILED", item["id"], str(e)[:300])
            if in_a_row >= 3:
                stop = True
    for item, job in cutting:
        try:
            job.result(); made += 1
        except Exception as e:
            failed.append(item["id"]); print("FAILED cut-out", item["id"], str(e)[:300])
    push(f"{made} new pieces")
    done = first + len(chunk)
    per = (time.time() - start) / done
    print(f"{done}/{len(todo)}  ~{per * (len(todo) - done) / 60:.0f} min left")
    if stop:
        print("Stopping: 3 pieces in a row failed (see the errors above). Fix the cause, then Run all again.")
        break
print("done:", made, "made,", len(failed), "failed:", failed)
"""

LOOK = r"""
# 6. A quick look at what this run made
names = [i["id"] for i in todo if os.path.exists(f"final/{i['id']}.png")][:48]
cell, cols = 220, 8
if names:
    sheet = Image.new("RGBA", (cell * cols, cell * ((len(names) + cols - 1) // cols)), (143, 207, 95, 255))
    for k, n in enumerate(names):
        im = Image.open(f"final/{n}.png"); im.thumbnail((cell - 20, cell - 20))
        sheet.alpha_composite(im, ((k % cols) * cell + (cell - im.width) // 2, (k // cols) * cell + (cell - im.height) // 2))
    display(sheet.convert("RGB"))
"""


def build():
    cells = [{"cell_type": "markdown", "metadata": {}, "source": INTRO.strip("\n").splitlines(True)}]
    for src in (SETTINGS, INSTALL, REPO, MODEL, MAKE, LOOK):
        cells.append({"cell_type": "code", "metadata": {}, "execution_count": None, "outputs": [],
                      "source": src.strip("\n").splitlines(True)})
    return {"cells": cells, "metadata": {"accelerator": "GPU", "colab": {"provenance": []},
            "kernelspec": {"display_name": "Python 3", "name": "python3"}, "language_info": {"name": "python"}},
            "nbformat": 4, "nbformat_minor": 0}


if __name__ == "__main__":
    import sys
    text = json.dumps(build(), indent=1) + "\n"
    path = os.path.join(ROOT, "tools", "generate_art.ipynb")
    if "--check" in sys.argv:
        if open(path).read() != text:
            sys.exit("tools/generate_art.ipynb is out of date: run python3 tools/make_notebook.py")
    else:
        open(path, "w").write(text)
        print("wrote", path)
