# uServer DataMgr

Data management microservices stack based on PostgreSQL (permanent data), Redis (ephemeral data) and Adminer (DB UI interface).

It's part of the [uServer](https://github.com/users/ferdn4ndo/projects/1) stack project.


### Prepare the environment

Copy both `adminer/.env.template` and `postgres/.env.template` to `adminer/.env` and `postgres/.env` (respectively) and edit them accordingly.

### Run the Application

```sh
docker-compose up --build
```
