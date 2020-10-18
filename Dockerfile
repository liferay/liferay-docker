FROM openjdk:8-jre
RUN java -version
RUN mkdir /opt/liferay
COPY ./liferay-ce-portal-7.0-ga6/ /opt/liferay/
WORKDIR /opt/liferay/tomcat-8.0.32
CMD bin/startup.sh start && tail -f logs/catalina.out
 
