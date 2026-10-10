import pathlib,subprocess,sys
root=pathlib.Path.cwd()
keep={'Finale.t.sol','Gameflow.t.sol','GameflowTransactions.t.sol','g_game_lifecycle.t.sol','g_game.t.sol','p_mobj.t.sol','st_stuff.t.sol','Intermission.t.sol','m_random.t.sol','v_video.t.sol','EpisodeStartup.t.sol','InputRuntime.t.sol','ProductionUI.t.sol','EpisodeLifecycle.t.sol','GameflowE1M1.t.sol','PointerHighBytes.t.sol','CompositeBacking.t.sol','r_data.t.sol','z_zone_backing.t.sol','z_zone_initialization.t.sol','z_zone.t.sol','r_draw.t.sol','p_enemy.t.sol'}
selected=sorted(str(p) for p in pathlib.Path('test').rglob('*.t.sol') if p.name in keep)
assert {pathlib.Path(p).name for p in selected}==keep
skips=sorted({p.name for p in pathlib.Path('test').rglob('*.t.sol') if p.name not in keep})
skips += ['GameplayProbe.sol','RendererProbe.sol','WadResourcesProbe.sol','EpisodeResourcesProbe.sol','EpisodeStartupProbe.sol','IntermissionProbe.sol','CheatProbe.sol','AutomapProbe.sol','VideoProbe.sol','SpeedrunProbe.sol','SpeedrunVideoProbe.sol','Doom.sol']
cmd=['.toolchain/bin/forge','test','--offline','--no-dynamic-test-linking','--fuzz-seed','0x414','--match-path','{'+','.join(selected)+'}','--skip',*skips,'-vv']
print('Selected roots:',selected,flush=True)
sys.exit(subprocess.run(cmd).returncode)
