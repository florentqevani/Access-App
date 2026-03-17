# Tokens and Sessions 

## How the Tokens and Sessions Work

- User sends credentials to the server.
- Server takes the credentials and verifyes them.
- If the credentials that user sended are the same as those stored in the database. 
- When verification comes true, server gives user a token.
- This token stores users session, users credentials and users permissions.
- After the server gives user this token, then can the user login.


## Stored token

- backend is in charge of generating the token using JWT
- The token has a lifespan of 15 minutes for access and 7 days before it is revoked.
- Token after being issued by the server is stored in `../local_data_source.dart` in the flutter application


## Token Explaination
- Token Example: 
`eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJjYWVlNjBmNC04N2FjLTRmZTItYTZiMi0yYTI2MjBmMWQ1MTkiLCJlbWFpbCI6InVzZXJAZ21haWwuY29tIiwicm9sZSI6InVzZXIiLCJwZXJtaXNzaW9ucyI6W10sInR5cGUiOiJhY2Nlc3MiLCJpYXQiOjE3NzM0MDUxNTUsImV4cCI6MTc3MzQwNjA1NX0.ipGnMZHRCks7Wj-EOxR7pIMD0ZjZlYVm8dORLwSlbvQ`

- A token is composed of 3 parts: 

- Header: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9`
- Payload:  `eyJzdWIiOiJjYWVlNjBmNC04N2FjLTRmZTItYTZiMi0yYTI2MjBmMWQ1MTkiLCJlbWFpbCI6InVzZXJAZ21haWwuY29tIiwicm9sZSI6InVzZXIiLCJwZXJtaXNzaW9ucyI6W10sInR5cGUiOiJhY2Nlc3MiLCJpYXQiOjE3NzM0MDUxNTUsImV4cCI6MTc3MzQwNjA1NX0`

- Signature: `ipGnMZHRCks7Wj-EOxR7pIMD0ZjZlYVm8dORLwSlbvQ`

- Header decides the token type and configuration
- Payload has login credentials, user permissions and meta data like logs
- Signature is the security verification

