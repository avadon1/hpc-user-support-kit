# T1: job pending

## User message

> Hi support,
>
> I submitted a job about 3 hours ago and it's still sitting in the queue. Nothing is happening. The job ID is 4471. I'm using partition `normal` and I requested 64 CPUs and 256G of memory for 7 days. I need this to finish by next Friday — it's for a paper deadline. Can you check if something is wrong with the cluster?
>
> Thanks,
> A. Researcher

## Clarifying questions

* Do you have other jobs running/submitted?
* No
* What does your workload actually need? (Is it possible to run on fewer CPUs/less memory?)
* Not possible
* Have you successfully run jobs on this cluster before?
* No
## Diagnostics

### Support Response_1

Could you please try the following commands and reply with the relevant outputs.
Please (if possible) do not reply with screenshots, but copy the whole outputs directly from the terminal. 

```bash
squeue -j 4471 -o "%.18i %.9P %.8T %.10M %.6D %R"
scontrol show job 4471 | sed -n '1,200p'
sacct -j 4471 --format=JobID,State,ExitCode,Elapsed,AllocCPUS,ReqMem%12,MaxRSS%12
```

### User Response_1

- `squeue` output:
    - **Example output (illustrative)**
    -  ```             4471       normal  PENDING       0:00      1 Resources```
- `scontrol show job` snippet:
    - **Example output (illustrative)**
    - JobId=4471 JobName=train
      UserId=youruser(1001) GroupId=yourgroup(1001) MCS_label=N/A
      Priority=12345 Nice=0 Account=research QOS=normal
      JobState=PENDING Reason=Resources Dependency=(null)
      Requeue=1 Restarts=0 BatchFlag=1 Reboot=0 ExitCode=0:0
      SubmitTime=2026-02-08T09:12:34 EligibleTime=2026-02-08T09:12:34
      StartTime=Unknown EndTime=Unknown Deadline=N/A
      Partition=normal AllocNode:Sid=login01:3120
      ReqNodeList=(null) ExcNodeList=(null)
      NodeList=(null)
      NumNodes=1-1 NumCPUs=64 NumTasks=1 CPUs/Task=64 ReqB:S:C:T=0:0:*:*
      TRES=normal=64,mem=256G,node=1,billing=64
      Socks/Node=* NtasksPerN:B:S:C=0:0:*:* CoreSpec=*
      MinCPUsNode=64 MinMemoryNode=256G MinTmpDiskNode=0
      Features=(null) DelayBoot=00:00:00
      OverSubscribe=OK Contiguous=0 Licenses=(null) Network=(null)
      Command=/home/youruser/project/train.slurm
      WorkDir=/home/youruser/project
      StdOut=/home/youruser/project/slurm-48219.out
      StdErr=/home/youruser/project/slurm-48219.err
- `sacct` output:
    - **Example output (illustrative)**
-         JobID      State	 ExitCode    Elapsed AllocCPUS       ReqMem       MaxRSS
	------------ ---------- -------- ---------- --------- ------------ ------------
	4471        PENDING    0:0      00:00:00         64       256Gn          0K


## Findings

- Pending reason:
- **Resources Dependency=(null)**
- Likely root cause:
- **Resources**
- Request might not fit node size in the desired partition `normal`
- Ask user to check node size in partition `normal`- are there nodes with the desired resources
- Refer to site docs/ask support - what node sizes are available in the different partitions-> notify user if there is **no existing** node with the specified parameters (64 CPUs, 256G RAM)
- The user requested **1 node with 64 CPUs, 256G memory for 7 days
- This is fairly large request
- There might be no nodes available to match the request right now
- Request like that - large CPU/memory/time requirements are much more likely to result in longer queue times due to the status of `QoS = normal`
- What is _not_ happening (ruled out):
- **Priority**
- **QOSMaxWallDurationPerJobLimit**
- **AssocGrp*Limit / MaxJobs / MaxSubmit**
- **InvalidAccount / InvalidQOS / PartitionDown / ReqNodeNotAvail**
## Resolution

1. Ask the user to check if requested node size exists in partition `normal`
* `sinfo -s` (list partitions + time limits)
- `scontrol show partition normal` (policy/limits)
- `sinfo -p normal -N -o "%N %c %m %t"` (node CPU/mem summary)
2. Advise the user to submit a job with smaller resource allocation in order to verify that the root cause is the large resource request and not something else.
3. Ask if higher-priority QoS is available for the account in question. 
* Yes - Advice the user to try using `--qos=...`
* No - escalate to discuss allocation/priority with admins

## Prevention

* Before submitting a workload double check to make sure that the requested node size exists in the desired partition.
* Before submitting a large request - submit a trivial test job to verify that there is no problem with services and user access controls/credentials.
* Very large requests need to be requested with the appropriate timing in mind - longer queue times and delayed execution times are to be expected when very large resource allocations are requested

## Escalate when

* No partition/node combination on this cluster can fit 64 CPUs + 256G
* User needs a QoS/priority change (policy decision, not user-level fix)
* Job still pending after resource reduction (possible scheduler/config issue)

## References

- `docs/slurm_basics.md` (pending reasons + commands)
- `docs/support_playbook.md` (triage workflow)
- (Any relevant site policy links if applicable)
