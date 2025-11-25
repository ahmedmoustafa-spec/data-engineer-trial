[Start] 
   |
   +--> [Azure Function: Fetch API Data] --(Success)--> [Copy Data: CRM Blob -> SQL Staging]
                                    |                                  |
   (On Failure) <-------------------+                                  |
        |                                                              v
[Web Activity: Slack Alert] <--------------------------- [Copy Data: Usage Blob -> SQL Staging]
        ^                                                              |
        |                                                              v
   (On Failure) <--------------------------------------- [Stored Proc: Transform & Load Target]