#!/bin/bash
#$1 : Folder .git untuk di scan
#$2 : Folder untuk menyimpan hasil
function init_header() {
    cat <<EOF
###########################################################################
# 死神(Shinigami) created by : Yogi Junior                                        
#                                                                        
# Developed and maintained by @yogijr5                                   
#
# Use at your own risk. Usage might be illegal in certain circumstances. 
# Only for Security Advisory & Defense!
###########################################################################
EOF
}

init_header

if [ $# -ne 2 ]; then
	echo -e "\e[33m[*] Perintah: shinigami.sh GIT-DIR DEST-DIR\e[0m";
	exit 1;
fi

if [ ! -d "$1/.git" ]; then
	echo -e "\e[31m[-] Tidak ditemukan folder .git\e[0m";
	exit 1;
fi

if [ ! -d "$2" ]; then
	echo -e "\e[33m[*] Folder Tujuan tak ditemukan\e[0m";
    echo -e "\e[32m[*] Membuat...\e[0m"
    mkdir "$2"
fi

function traverse_tree() {
	local tree=$1
	local path=$2
	
    #Membaca blob/pohon informasi dari root tree
	git ls-tree $tree |
	while read leaf; do
		type=$(echo $leaf | awk -F' ' '{print $2}') #grep -oP "^\d+\s+\K\w{4}");
		hash=$(echo $leaf | awk -F' ' '{print $3}') #grep -oP "^\d+\s+\w{4}\s+\K\w{40}");
		name=$(echo $leaf | awk '{$1=$2=$3=""; print substr($0,4)}') #grep -oP "^\d+\s+\w{4}\s+\w{40}\s+\K.*");
		
        # Mengambil data blob
		git cat-file -e $hash;
		#Mengizinkan .git invalid (e.g. Salah satunya hilang)
		if [ $? -ne 0 ]; then
			continue;
		fi	
		
		if [ "$type" = "blob" ]; then
			echo -e "\e[32m[+] File Ditemukan: $path/$name\e[0m"
			git cat-file -p $hash > "$path/$name"
		else
			echo -e "\e[32m[+] Folder Ditemukan: $path/$name\e[0m"
			mkdir -p "$path/$name";
			#Recursively traverse sub trees
			traverse_tree $hash "$path/$name";
		fi
		
	done;
}

function traverse_commit() {
	local base=$1
	local commit=$2
	local count=$3
	
    #Membuat folder untuk commit data
	echo -e "\e[32m[+] Menemukan commit: $commit\e[0m";
	path="$base/$count-$commit"
	mkdir -p $path;
    #Menambah meta information
	git cat-file -p "$commit" > "$path/commit-meta.txt"
    #Coba untuk extrak konten dari root tree
	traverse_tree $commit $path
}

#Direktori aktif ke yang lainnya.
OLDDIR=$(pwd)
TARGETDIR=$2
COMMITCOUNT=0;

#Jika Path tidak konsisten, Tambahkan prepend CWD
if [ "${TARGETDIR:0:1}" != "/" ]; then
	TARGETDIR="$OLDDIR/$2"
fi

cd $1

#Extrak semua objek hash
find ".git/objects" -type f | 
	sed -e "s/\///g" |
	sed -e "s/\.gitobjects//g" |
	while read object; do
	
	type=$(git cat-file -t $object)
	
    # Hanya Menganalisa commit objek
	if [ "$type" = "commit" ]; then
		CURDIR=$(pwd)
		traverse_commit "$TARGETDIR" $object $COMMITCOUNT
		cd $CURDIR
		
		COMMITCOUNT=$((COMMITCOUNT+1))
	fi
	
	done;

cd $OLDDIR;