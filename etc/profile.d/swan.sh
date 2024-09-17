export LD_LIBRARY_PATH=/usr/local/lib/
SRCTMP=`mktemp`
#to make krb5 work, temporary
source <(grep KRB5CCNAME /scratch/rcastell/.bash_profile )
/usr/local/bin/python3 -E << EOF
from pathlib import Path
envtowrite=[]
for p in [Path.cwd(), *Path.cwd().parents]:
	print(p)
	try:
		with open(p / ".swanproject") as f:
			print(f'reading file from {p}')
			for line in f.readlines():
				name, value = line.rstrip("\n").split("=", 1)
				envtowrite.append(f'export {name}={value}\n')
		with open("$SRCTMP",'w') as f:
			f.writelines(envtowrite)
		break
	except PermissionError as e:
		## it means we are out of the hierarchy
		break
	except FileNotFoundError as e:
		## this folder doesn't contain a .swanproject file
		pass
EOF

if [ $? -eq 0 ];
	then
		source $SRCTMP;
	else
		echo 'no env file set';
	       	source /scratch/rcastell/.bash_profile
fi
