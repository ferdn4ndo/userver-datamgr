# uServer DataMgr

Data management microservices stack based on PostgreSQL (permanent data), Redis (ephemeral data) and Adminer (DB UI interface).

It's part of the [uServer](https://github.com/users/ferdn4ndo/projects/1) stack project.


### Prepare the environment

Copy the environment template files...

```
cp adminer/.env.template adminer/.env
cp backup/.env.template backup/.env
cp postgres/.env.template postgres/.env
``` 
...and edit them accordingly.

### Run the Application

```sh
docker-compose up --build
```
