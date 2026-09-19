[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ffmpeg = 'C:\Users\Usuario\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.1-full_build\bin\ffmpeg.exe'
$root = Split-Path -Parent $PSScriptRoot
$raw = Join-Path $root 'media\raw'
$prints = Join-Path $root 'prints_playstore'
$videoDir = Join-Path $root 'videos'
$audioDir = Join-Path $root 'narracoes'
$tmpDir = Join-Path $root 'media\build'

foreach ($path in @($videoDir, $audioDir, $tmpDir)) {
    New-Item -ItemType Directory -Force -Path $path | Out-Null
}

Add-Type -AssemblyName System.Speech

$narrations = @(
    [pscustomobject]@{
        Id = '01_primeiro_acesso'
        Duration = 26
        Text = 'No primeiro acesso, informe nome, WhatsApp e CPF para criar o cadastro local. Leia as informações de privacidade e avance. Em seguida, conheça a apresentação do Tutor TDS e escolha uma cartilha para aprender no seu ritmo.'
        Srt = @'
1
00:00:00,000 --> 00:00:06,000
No primeiro acesso, informe os dados para criar o cadastro local.

2
00:00:06,000 --> 00:00:15,000
Leia as informações de privacidade e avance pela apresentação.

3
00:00:15,000 --> 00:00:26,000
Depois, escolha uma cartilha e aprenda no seu ritmo.
'@
    }
    [pscustomobject]@{
        Id = '02_estudo_com_ia'
        Duration = 32
        Text = 'Na central Estudar com IA, escolha a cartilha que deseja revisar. Você encontra cartões de estudo, quiz com correção, resumo e simulado. O chat explica o conteúdo passo a passo. Use a inteligência artificial como apoio e confirme informações importantes na cartilha e com a equipe.'
        Srt = @'
1
00:00:00,000 --> 00:00:10,000
Escolha a cartilha que deseja revisar na central Estudar com IA.

2
00:00:10,000 --> 00:00:22,000
Use cartões, quiz com correção, resumo e simulado para revisar.

3
00:00:22,000 --> 00:00:32,000
O chat ajuda a explicar. Confirme informações importantes na cartilha.
'@
    }
    [pscustomobject]@{
        Id = '03_agricultura_e_safs'
        Duration = 30
        Text = 'Nas aulas de Agricultura Sustentável e Sistemas Agroflorestais, o aplicativo transforma a cartilha em uma conversa interativa. Leia o tema, avance nas perguntas e retome conceitos de agroecologia, SAFs e irrigação de baixo custo. Para casa, oriente a revisão dos pontos que cada estudante ainda precisa fortalecer.'
        Srt = @'
1
00:00:00,000 --> 00:00:10,000
Agricultura Sustentável e SAFs ganham uma conversa interativa.

2
00:00:10,000 --> 00:00:20,000
Leia o tema, avance nas perguntas e retome os conceitos essenciais.

3
00:00:20,000 --> 00:00:30,000
Para casa, revise os pontos que ainda precisam ser fortalecidos.
'@
    }
    [pscustomobject]@{
        Id = '04_guia_para_tutores'
        Duration = 40
        Text = 'Para apoiar uma aula presencial, combine um objetivo prático com uma cartilha. Antes do encontro, peça uma leitura curta. Durante a aula, avance em um trecho e discuta exemplos locais. Depois, indique cartões, quiz ou resumo como tarefa de reforço. Em Agricultura, trabalhe agroecologia, SAFs e políticas públicas e comercialização. Em Educação Financeira, retome orçamento, crédito, juros e metas. O Tutor complementa a explicação; a cartilha e a mediação do educador continuam sendo a referência.'
        Srt = @'
1
00:00:00,000 --> 00:00:10,000
Combine cada aula presencial com um objetivo prático e uma cartilha.

2
00:00:10,000 --> 00:00:20,000
Antes, peça uma leitura curta. Durante, avance em um trecho e discuta exemplos locais.

3
00:00:20,000 --> 00:00:30,000
Depois, use cartões, quiz ou resumo como tarefa de reforço.

4
00:00:30,000 --> 00:00:40,000
O app complementa a aula: a cartilha e a mediação do educador são a referência.
'@
    }
    [pscustomobject]@{
        Id = '05_encontrar_na_play_store'
        Duration = 20
        Text = 'Para encontrar o aplicativo, abra a Google Play Store e pesquise por Tutor TDS. Confirme o nome Tutor TDS e o ícone com as letras TDS nas cores azul, amarelo, verde e vermelho. Na página do aplicativo, confira as capturas de tela, a descrição e o responsável antes de instalar ou atualizar.'
        Srt = @'
1
00:00:00,000 --> 00:00:07,000
Abra a Google Play Store e pesquise por Tutor TDS.

2
00:00:07,000 --> 00:00:14,000
Confirme o nome e o ícone com as letras TDS coloridas.

3
00:00:14,000 --> 00:00:20,000
Confira a página do app antes de instalar ou atualizar.
'@
    }
)

function New-NarrationAssets {
    param([Parameter(Mandatory)]$Narration)

    $wav = Join-Path $audioDir "$($Narration.Id).wav"
    $mp3 = Join-Path $audioDir "$($Narration.Id).mp3"
    $srt = Join-Path $videoDir "$($Narration.Id).srt"

    $voice = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $voice.SelectVoice('Microsoft Maria Desktop')
    $voice.Rate = -1
    $voice.Volume = 100
    $voice.SetOutputToWaveFile($wav)
    $voice.Speak($Narration.Text)
    $voice.Dispose()

    & $ffmpeg -hide_banner -loglevel error -y -i $wav -c:a libmp3lame -q:a 2 $mp3
    if ($LASTEXITCODE -ne 0) { throw "Falha ao codificar a narração $($Narration.Id)." }
    Set-Content -LiteralPath $srt -Value $Narration.Srt.Trim() -Encoding utf8

    return [pscustomobject]@{ Wav = $wav; Mp3 = $mp3; Srt = $srt }
}

function Add-NarrationAndSubtitles {
    param(
        [Parameter(Mandatory)][string]$Visual,
        [Parameter(Mandatory)]$Narration,
        [Parameter(Mandatory)]$Assets
    )

    $output = Join-Path $videoDir "$($Narration.Id).mp4"
    & $ffmpeg -hide_banner -loglevel error -y `
        -i $Visual -i $Assets.Mp3 -i $Assets.Srt `
        -map 0:v:0 -map 1:a:0 -map 2:0 `
        -c:v copy -c:a aac -b:a 192k -c:s mov_text `
        -metadata:s:s:0 language=por `
        -filter:a "apad=pad_dur=$($Narration.Duration + 3)" `
        -t $Narration.Duration -movflags +faststart $output
    if ($LASTEXITCODE -ne 0) { throw "Falha ao finalizar $($Narration.Id)." }
    return $output
}

function Render-Visual {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string[]]$InputArgs,
        [Parameter(Mandatory)][string]$Filter
    )

    $output = Join-Path $tmpDir "$Id.visual.mp4"
    & $ffmpeg -hide_banner -loglevel error -y @InputArgs `
        -filter_complex $Filter -map '[v]' -r 30 -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -movflags +faststart $output
    if ($LASTEXITCODE -ne 0) { throw "Falha ao renderizar o visual $Id." }
    return $output
}

$media = @{}
foreach ($narration in $narrations) {
    $media[$narration.Id] = New-NarrationAssets -Narration $narration
}

$crop = 'crop=953:1694:64:102,scale=1080:1920:flags=lanczos,setsar=1'

$visual = Render-Visual -Id '01_primeiro_acesso' -InputArgs @(
    '-loop','1','-t','6','-i',(Join-Path $prints '01_primeiro_acesso.png'),
    '-i',(Join-Path $raw 'onboarding_clip_raw.mp4')
) -Filter "[0:v]fps=30,format=yuv420p[v0];[1:v]$crop,fps=30,format=yuv420p[v1];[v0][v1]concat=n=2:v=1:a=0[v]"
Add-NarrationAndSubtitles -Visual $visual -Narration $narrations[0] -Assets $media[$narrations[0].Id] | Out-Null

$visual = Render-Visual -Id '02_estudo_com_ia' -InputArgs @(
    '-i',(Join-Path $raw 'study_hub_clip_raw.mp4'),
    '-loop','1','-t','6','-i',(Join-Path $prints '06_tutor_ia_agricultura.png')
) -Filter "[0:v]$crop,fps=30,format=yuv420p[v0];[1:v]fps=30,format=yuv420p[v1];[v0][v1]concat=n=2:v=1:a=0[v]"
Add-NarrationAndSubtitles -Visual $visual -Narration $narrations[1] -Assets $media[$narrations[1].Id] | Out-Null

$visual = Render-Visual -Id '03_agricultura_e_safs' -InputArgs @(
    '-i',(Join-Path $raw 'agriculture_clip_raw.mp4'),
    '-loop','1','-t','6','-i',(Join-Path $prints '06_tutor_ia_agricultura.png')
) -Filter "[0:v]$crop,fps=30,format=yuv420p[v0];[1:v]fps=30,format=yuv420p[v1];[v0][v1]concat=n=2:v=1:a=0[v]"
Add-NarrationAndSubtitles -Visual $visual -Narration $narrations[2] -Assets $media[$narrations[2].Id] | Out-Null

$visual = Render-Visual -Id '04_guia_para_tutores' -InputArgs @(
    '-loop','1','-t','8','-i',(Join-Path $prints '07_cursos_disponiveis.png'),
    '-loop','1','-t','8','-i',(Join-Path $prints '03_agricultura_interativa.png'),
    '-loop','1','-t','8','-i',(Join-Path $prints '08_educacao_financeira_ia.png'),
    '-loop','1','-t','8','-i',(Join-Path $prints '05_cartoes_quiz_resumo.png'),
    '-loop','1','-t','8','-i',(Join-Path $prints '06_tutor_ia_agricultura.png')
) -Filter '[0:v]fps=30,format=yuv420p[v0];[1:v]fps=30,format=yuv420p[v1];[2:v]fps=30,format=yuv420p[v2];[3:v]fps=30,format=yuv420p[v3];[4:v]fps=30,format=yuv420p[v4];[v0][v1][v2][v3][v4]concat=n=5:v=1:a=0[v]'
Add-NarrationAndSubtitles -Visual $visual -Narration $narrations[3] -Assets $media[$narrations[3].Id] | Out-Null

$visual = Render-Visual -Id '05_encontrar_na_play_store' -InputArgs @(
    '-loop','1','-t','7','-i',(Join-Path $prints '01_primeiro_acesso.png'),
    '-loop','1','-t','6','-i',(Join-Path $prints '07_cursos_disponiveis.png'),
    '-loop','1','-t','7','-i',(Join-Path $prints '04_central_estudar_ia.png')
) -Filter '[0:v]fps=30,format=yuv420p[v0];[1:v]fps=30,format=yuv420p[v1];[2:v]fps=30,format=yuv420p[v2];[v0][v1][v2]concat=n=3:v=1:a=0[v]'
Add-NarrationAndSubtitles -Visual $visual -Narration $narrations[4] -Assets $media[$narrations[4].Id] | Out-Null

Get-ChildItem -LiteralPath $videoDir -File | Select-Object Name,Length,LastWriteTime
