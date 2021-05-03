#!/bin/bash

ver () {
    echo Chapa - chia plotter helper version 0.02
}

usage () {
    echo Usage:
    echo
    echo chapa start queue_name - start creating plots
    echo chapa status - show current plotting status
    echo
    echo if you need to change some plotting params, change it directly in script file

}

startchecks () {

# check for main chia file
    if [ ! -f "$script_path/venv/bin/chia" ] 
     then 
        echo "chia file not exist" 
        exit 5
    fi

# screen required for this script , and we check it
    if ! command -v screen &> /dev/null
     then 
        echo "cant find screen programm, install it"
        exit 5
    fi

    # pidof required for this script , and we check it
    if ! command -v pidof &> /dev/null
     then 
        echo "cant find pidof programm,  install it"
        exit 5
    fi

# detecting first start
    if [ ! -d $workpath ] || [ ! -d $tmpdir ] || [ ! -d $preplotdir ]
    then
        echo "Firststart detected creating workpath directories"
        mkdir $workpath $tmpdir $preplotdir > /dev/null 2>&1
	touch $workpath/fingerprint.txt > /dev/null 2>&1
    fi
    if [ -d "$workpath" ]; then echo "Workpath created at ${workpath}"; fi
    if [ ! -s "$workpath/fingerprint.txt" ]
    then 
	echo ""
	echo "Put your chia keys fingerprint into ${workpath}/fingerprint.txt"
	echo "you can find fingerprint by running chia show keys in chia cli"
	exit 6
    else
	fingerprint=$(cat $workdir/fingerprint.txt)
    fi


}


# settings
script_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
workpath="$script_path"/chapa
tmpdir="$workpath"/tmp
preplotdir="$workpath"/preplot
plotdir="$workdir"/finalplot
buffer="3389"
threads="2"
typeset -i i plotcount
plotcount=3


# check we have required stuff before start
startchecks

case "$1" in
"start")
    if [ -z "$2" ]; then usage; exit 6; fi
    for ((i=1;i<=plotcount;++i)); do
	runthreads=0
        mkdir "${tmpdir}/${2}_${i}"
        screen -dmS "${2}_${i}" -L -Logfile "${workpath}/log/${2}_${i}_screen.log"
	screen -S $2_$i -X stuff "source ${script_path}/venv/bin/activate\n"
        screen -S $2_$i -X stuff "chia plots create -k32 -u128 -b${buffer} -r${threads} -x -t${tmpdir}/${2}_${i} -d${preplotdir} -a${fingerprint}\n"
	sleep 5
	plotterpid=$(pidof -x -s chia)
	runthreads=$(ps H -p "${plotterpid}"  | grep "${plotterpid}" | wc -l)
	if [ $runthreads > 0 ]
	then
	    echo "Started plot ${i} in queue ${2}, process pid is ${plotterpid}"
	    status="running"
	    progress="started"
	else
	    echo "Error cant start plot ${i} see screen logfile ${2}_${i}_screen.log for details"
	fi
	let "runthreads=$runthreads-1"
	echo $2 $i $plotterpid $runthreads $status $progress >> $workpath/pids.txt
    done
    exit 0


;;
"stop")
    if [ -z "$2" ]; then usage; exit 6; fi
    echo "Stop plotting will be implemented soon..."

;;

"status")

    echo "Plotting status:"
    echo ""
    if [ ! -f $workpath/pids.txt ]; then echo "Looks like plotting is not running or it started not from chapa"; exit 0; fi
    while read line
    do
	qs=$(echo $line|awk '{ print $1 }')
	index=$(echo $line|awk '{ print $2 }')
	pid=$(echo $line|awk '{ print $3 }')
	status=$(echo $line|awk '{ print $4 }')
	progress=$(echo $line|awk '{ print $5 }')
	runthreads=$(ps H -p "${pid}"  | grep "${pid}" | wc -l)
	let "runthreads=$runthreads-1"
	if ps -p "${pid}"|grep -q $pid
	then
	    status="running"
	    if cat $workpath/log/"${qs}_${index}_screen.log"|grep -q "phase 1/4"; then progress="phase1"; fi
	    if cat $workpath/log/"${qs}_${index}_screen.log"|grep -q "phase 2/4"; then progress="phase2"; fi
	    if cat $workpath/log/"${qs}_${index}_screen.log"|grep -q "phase 3/4"; then progress="phase3"; fi
	    if cat $workpath/log/"${qs}_${index}_screen.log"|grep -q "phase 4/4"; then progress="phase4"; fi
	    if cat $workpath/log/"${qs}_${index}_screen.log"|grep -q "Renamed final file"; then progress="finished"; fi
	else
	    status="rip"
	fi
	echo $qs $index $pid $runthreads $status $progress >> $workpath/pidsupdate.txt
    done < $workpath/pids.txt
    mv $workpath/pidsupdate.txt $workpath/pids.txt
    echo "Queue Index Pid Threads Status Progress"
    echo ""
    cat $workpath/pids.txt
    echo ""
    exit 0
;;

"pause")
    if [ -z "$2" ]; then usage; exit 6; fi
    echo "This function will be implemented soon..."
;;
"resume")
    if [ -z "$2" ]; then usage; exit 6; fi
    echo "This function will be implemented soon..."
;;
"-v")
    ver
    exit 0
;;

*)
    usage
    exit 6
;;
esac