# Moonlit Hearth shell colours (appended to ~/.bashrc by install.sh).
# eza: snow dirs, pine executables, amber sizes, ember write bits, frost dates.
export EZA_COLORS="di=1;38;2;212;227;240:ex=1;38;2;143;185;168:ln=38;2;196;184;232:or=38;2;210;122;106:\
sn=38;2;240;196;122:sb=38;2;138;98;72:da=38;2;93;117;144:uu=38;2;163;185;204:gu=38;2;111;159;216:\
ur=38;2;240;196;122:uw=38;2;210;122;106:ux=38;2;143;185;168:ue=38;2;143;185;168:\
gr=38;2;111;159;216:gw=38;2;180;110;100:gx=38;2;110;150;135:tr=38;2;111;159;216:tw=38;2;180;110;100:tx=38;2;110;150;135:\
xx=38;2;31;51;80:ga=38;2;143;185;168:gm=38;2;240;196;122:gd=38;2;210;122;106:gn=38;2;196;184;232"

# fzf: transparent, night selection, moonlight matches, ❄ pointer like the prompt.
export FZF_DEFAULT_OPTS="\
--color=bg:-1,bg+:#1a2c45,fg:#a3b9cc,fg+:#e4eef7,hl:#8fbbe0,hl+:#f0c47a \
--color=border:#1f3a5c,label:#8fbbe0,prompt:#8fbbe0,pointer:#f0c47a,marker:#8fb9a8 \
--color=spinner:#a99ad8,info:#5d7590,header:#a99ad8,query:#e4eef7,gutter:-1,scrollbar:#1f3a5c \
--layout=reverse --border=rounded --border-label=' ☾ moonlit hearth ' --border-label-pos=3 \
--prompt='☾ ' --pointer='❄' --marker='+' --info=inline-right --height=45%"
