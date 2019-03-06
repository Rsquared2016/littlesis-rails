import React from 'react';

const Image = ({entity}) => {
  return <div className="potential-match-entity-image-wrapper">
           <img
             src={entity.image_url}
             alt={`Image of LittleSis entity: ${entity.name}`}
           />
         </div>;

};

const Entity = ({entity}) => {

  return <div className="potential-match-entity">
           <a href={entity.url} ><h1>{entity.name}</h1></a>
           <p className="potential-match-entity-blurb">{entity.blurb}</p>
         </div>;
  
};


export default function PotentialMatch(props) {
  const entity = props.match.entity;
  
  return <div className="potential-match-card">
           <Image entity={entity} />
           <Entity entity={entity} />
         </div>;
};
