from gitlab/gitlab-runner:latest

ENV URL=CI-SERVER-URL
ENV TOKEN=CI-SERVER-TOKEN

# It could be shell
ENV EXECUTOR=RUNNER-EXECUTOR

COPY ./context/runner-init.sh /
RUN chmod a+x /runner-init.sh

ENTRYPOINT ["/usr/bin/dumb-init", "/runner-init.sh"]

CMD ["run", "--user=gitlab-runner", "--working-directory=/home/gitlab-runner"]
